#!/usr/bin/env ruby
# frozen_string_literal: true

# Imports the useful part of Noah Gibbs' Shoes-Spec corpus into spec/shoes_spec/.
#
#   ruby spec/import_shoes_spec.rb PATH/TO/shoes-spec/cases
#
# Only cases whose test code makes at least one real assertion come across: not skip-first,
# not `assert true`, not comments-only, not existence-only (`assert para()`), and not
# dom_html (webview-only). Cases with identical app code are merged into the one with the
# most real assertions; the others are listed as `duplicates:` in its front matter.
# Trivial finder misuse is fixed on the way in (button("Save") becomes find_button("Save")).
#
# The import is idempotent: it rewrites spec/shoes_spec/ from scratch, including
# spec/shoes_spec/import_manifest.yml, which records every source case and what happened to it.
# To change an imported case, add a rule to RULINGS or FIXES below and re-run.

require "json"
require "yaml"
require "fileutils"

$LOAD_PATH.unshift File.expand_path("../scarpe-components/lib", __dir__)
module Scarpe; end
require "scarpe/components/errors"
require "scarpe/components/segmented_file_loader"

module ShoesSpecImport
  OUT = File.expand_path("shoes_spec", __dir__)
  MANIFEST = File.join(OUT, "import_manifest.yml")

  SKIPPED_CATEGORIES = {
    "test_code/" => "Shoes-Spec harness self-tests; spec/harness/ covers spec/run itself",
  }.freeze

  TITLE_FAMILY = "Lacci makes title, subtitle, banner and caption Para subclasses (element.title), so paras() " \
    "still includes them, and the finders go by size, so restyling the size loses the banner"
  NETWORK = "needs the network: the asserted text arrives from a download callback"

  # Test code for cases the corpus left skipping part way through, now that what they waited
  # for works. Each keeps the source's assertions and says why it replaces the skip.
  DRIVEN = {
    clock: <<~RUBY,
      # The clock draws everything from its animate block. The corpus asserted before the
      # first tick, which test code always runs ahead of (spec/README.md); the case advances
      # the frozen clock instead (spec/import_shoes_spec.rb, DRIVEN).
      assert_empty paras, "nothing is drawn before the first tick"
      advance(1.0 / 8)
      assert_equal 1, paras.size, "a tick draws the date and time"
      assert_includes para.text, ":", "hours and minutes"
      assert_equal 7, lines.size, "four hour marks and three hands"
      advance(1.0 / 8)
      assert_equal [1, 7], [paras.size, lines.size], "the next tick clears the face before drawing it again"
    RUBY
    mouse_detection: <<~RUBY,
      # animate reads self.mouse into the para. The corpus read the para before the first
      # frame; the case moves the pointer and advances one (spec/import_shoes_spec.rb, DRIVEN).
      assert_equal "", para.text, "nothing before the first frame"
      move_mouse 30, 40
      advance(1.0 / 10)
      assert_equal "mouse: 0, 30, 40", para.text, "a frame shows where the pointer is, with no button down"
    RUBY
    custom_list_box: <<~RUBY,
      # Custom list_box widget using the Observable pattern. The corpus stopped at
      # `skip "Requires Shoes::Widget and observer stdlib"`; both work, so the case drives it
      # (spec/import_shoes_spec.rb, DRIVEN).
      assert_equal "Any selection?", para().text
      assert_equal ["first", "second"], list_box().items
      list_box().trigger_change("second")
      assert_equal "Selection is second.", para().text
      edit_line().text = "third"
      find_button("ok").trigger_click
      assert_equal ["first", "second", "third"], list_box().items, "ok adds the edit line's text through the observer"
      find_button("collect").trigger_click
      assert_equal ["tsrif", "dnoces", "driht"], list_box().items, "collect reverses every item in place"
    RUBY
    path_animation: <<~RUBY,
      # Dragging the dot records a path; released, a turned square walks along it. The corpus
      # stopped at `skip "Interactive animation with mouse tracking"`; native can drag, so the
      # case drives it (spec/import_shoes_spec.rb, DRIVEN).
      assert_equal "reset", button().text
      assert_empty stack("@stack").contents, "nothing is drawn before the first frame"
      drag [200, 200], [240, 220], [280, 240]
      advance(1.0 / 24)
      drawn = stack("@stack").contents
      assert_equal 3, drawn.count { |shape| shape.is_a?(Shoes::Oval) }, "the dot and the two points it was dragged through"
      assert_equal 1, drawn.count { |shape| shape.is_a?(Shoes::Rect) }, "and, released, the square that walks the path"
    RUBY
    simple_downloader: <<~RUBY,
      # download() with :save, :progress and :finish. The corpus skipped it for want of network
      # access; a URL on a closed local port fails at once without leaving the machine, and
      # what the button appends does not wait for the download (spec/import_shoes_spec.rb, DRIVEN).
      assert_equal "Download", button().text
      url = "http://127.0.0.1:9/nothing.bin"
      edit_line().text = url
      button().trigger_click
      assert_includes paras.map(&:text), "\#{url} [cancel]", "the URL and its cancel link"
      assert_equal "Beginning transfer.", inscription().text
      assert_equal 0.0, progress().fraction, "a bar that has not moved yet"
    RUBY
  }.freeze

  # Rulings made after running the import under niente (see the manifest), by source path.
  # drop:    the case is wrong or untestable as written, and the reason says why.
  # expect:  written into the case's front matter with the reason; a Hash limits it to one display.
  # display: the case's display when it needs native input (drag, layout).
  # test:    test code that replaces the source's (DRIVEN).
  RULINGS = {
    "scarpe_examples/examples/legacy/for_playtest/expert/tooltips.sspec" =>
      { drop: "finds a para by its text, which finders do not support" },
    "scarpe_examples/examples/legacy/for_playtest/speedometer_app.sspec" =>
      { drop: "finds an edit_line by a text: hash, which finders do not support" },
    "scarpe_examples/examples/legacy/for_playtest/shoes-contrib/simple/simple-dialogs.sspec" =>
      { drop: "calls button() while the app has several buttons" },
    "scarpe_examples/examples/shoes_school.sspec" => { drop: "calls para() while the app has several paras" },
    "scarpe_examples/examples/legacy/for_playtest/good/plots.sspec" =>
      { drop: "plot is Shoes 3 only (examples/legacy/shoes3_only/README.md)" },
    "scarpe_examples/examples/ruby_racer.sspec" => { drop: "needs the benchmark gem, no longer a default gem in Ruby 4" },
    "scarpe_examples/examples/scarpe_ext.sspec" => { drop: "needs the webview-only :html feature" },
    "scarpe_examples/examples/legacy/for_playtest/shoes-contrib/app/download-and-save.sspec" => { drop: NETWORK },
    "scarpe_examples/examples/legacy/for_playtest/shoes-contrib/app/download.sspec" => { drop: NETWORK },
    "scarpe_examples/examples/legacy/for_playtest/shoes-contrib/app/get-google.sspec" => { drop: NETWORK },
    "scarpe_examples/legacy/for_playtest/shoes3-tests/curl/m1.sspec" => { drop: NETWORK },
    "scarpe_examples/legacy/for_playtest/shoes3-tests/curl/m2.sspec" => { drop: NETWORK },
    "scarpe_examples/legacy/for_playtest/shoes3-tests/curl/m3.sspec" => { drop: NETWORK },

    "scarpe_examples/examples/legacy/for_playtest/shoes-contrib/app/mouse-detection.sspec" =>
      { test: DRIVEN[:mouse_detection], display: "native" },
    "scarpe_examples/legacy/working/simple/clock.sspec" => { test: DRIVEN[:clock], display: "native" },
    "scarpe_examples/examples/shoes_splorer.sspec" =>
      { expect: "fail", reason: "text fragments such as code() live in their para's text items, not the drawable tree, so codes() finds none" },
    "scarpe_examples/legacy/for_playtest/shoes3-tests/radio/multiple.sspec" =>
      { expect: "fail", reason: "paras() returns drawables breadth-first, not in document order, so the start block's paras come first" },
    "scarpe_examples/examples/page_navigation_single_app.sspec" => { expect: "fail", reason: TITLE_FAMILY },
    "scarpe_examples/legacy/for_playtest/shoes-contrib/basic/shoes-notes.sspec" => { expect: "fail", reason: TITLE_FAMILY },
    "scarpe_examples/legacy/for_playtest/shoes-contrib/basic/two-column.sspec" => { expect: "fail", reason: TITLE_FAMILY },
    "scarpe_examples/legacy/for_playtest/shoes-contrib/elements/common-styles.sspec" => { expect: "fail", reason: TITLE_FAMILY },
    "scarpe_examples/legacy/for_playtest/shoes3-tests/opacity_test.sspec" => { expect: "fail", reason: TITLE_FAMILY },
    "scarpe_examples/legacy/working/philippe/guessing_game.sspec" => { expect: "fail", reason: TITLE_FAMILY },

    "scarpe_examples/examples/legacy/needs_deps/custom-list-box.sspec" => { test: DRIVEN[:custom_list_box] },
    "scarpe_examples/examples/legacy/for_playtest/simple/path-animation.sspec" =>
      { test: DRIVEN[:path_animation], display: "native" },
    "scarpe_examples/examples/legacy/for_playtest/shoes-contrib/simple/simple-downloader.sspec" =>
      { test: DRIVEN[:simple_downloader] },
  }.freeze

  # Mechanical rewrites of test code, applied to every imported case.
  FIXES = [
    # Finders take classes, "@ivar", "$global" or "id:N", never text (research 04, A5).
    [/\bbutton\(\s*(["'])(?![@$]|id:)([^"']*)\1\s*\)/, 'find_button(\1\2\1)'],
    # Webview-only dialog stubs, mapped onto the suite's stub_dialog.
    [/\bstub_alert\b(?:\(\))?/, "stub_dialog(:alert, nil)"],
    [/\bstub_(ask|confirm|ask_color|ask_open_file|ask_save_file|ask_open_folder|ask_save_folder)\(returns:\s*([^)]*)\)/,
     'stub_dialog(:\1, \2)'],
  ].freeze

  # One assertion statement, classified by how much it can prove.
  module Assertion
    VALUE_METHODS = /\A(assert_equal|assert_includes|assert_match|assert_in_delta|assert_operator|assert_kind_of|
      assert_instance_of|assert_predicate|assert_raises|assert_empty|assert_nil|assert_same|refute_equal|
      refute_includes|refute_match|refute_empty|refute_predicate|assert_output)\b/x
    COMPARISON = /==|!=|\.include\?|\.start_with\?|\.end_with\?|=~|\.match\?|\.checked\?|\.empty\?|\.nil\?|\.zero\?|
      \.is_a\?|\.kind_of\?|\.instance_of\?|\.all\?|\.none\?|\.any\?\s*\{/x
    LOWER_BOUND = /(\.length|\.size|\.count)\s*(>=?)\s*\d+/

    def self.kind(statement)
      return :trivial if statement =~ /\A(assert|refute)\s*\(?\s*(true|false)\s*\)?\s*(,|\z)/
      return :value if statement =~ VALUE_METHODS
      return :existence if statement =~ /\A(refute_nil|assert_not_nil)\b/
      return :existence if statement =~ LOWER_BOUND && statement !~ /==/
      return :value if statement =~ /\A(assert|refute)\b/ && statement =~ COMPARISON

      :existence
    end
  end

  class SourceCase
    attr_reader :path, :relative, :app_code, :test_code, :problem

    def initialize(root, path)
      @path = path
      @relative = path.delete_prefix(root + "/")
      _front_matter, segments = Scarpe::Components::SegmentedFileLoader.front_matter_and_segments_from_file(File.read(path))
      if segments.size == 2
        @app_code, test_code = segments.values
        @test_code = FIXES.reduce(test_code) { |code, (pattern, replacement)| code.gsub(pattern, replacement) }
      else
        @problem = "splits into #{segments.size} segments (a line of 5+ dashes in the app code)"
      end
    rescue StandardError, Psych::Exception => e
      @problem = "cannot parse: #{e.message.lines.first}"
    end

    def category
      File.dirname(relative).delete_prefix("scarpe_examples/")
    end

    def name
      File.basename(relative, ".sspec")
    end

    def app_key
      app_code.lines.map(&:rstrip).join("\n").strip
    end

    # Each assertion call with its continuation lines, e.g. "assert_equal 1,\n  para.text.size".
    def assertions
      statements = []
      code_lines.each do |line|
        if line =~ /\A(assert|refute|flunk)/
          statements << line
        elsif statements.last&.match?(/[,(|&\\]\z/)
          statements[-1] = "#{statements.last} #{line}"
        end
      end
      statements
    end

    def assertion_kinds
      assertions.map { |statement| Assertion.kind(statement) }
    end

    def code_lines
      test_code.lines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
    end

    def real_assertions
      assertion_kinds.count(:value)
    end

    # Why this case is not worth importing, or nil.
    def rejection
      return problem if problem

      SKIPPED_CATEGORIES.each { |prefix, reason| return reason if relative.start_with?(prefix) }
      code = code_lines.join("\n")
      return "uses dom_html (webview only)" if code.include?("dom_html")
      return "skip-only (skips before asserting anything)" if code.strip.start_with?("skip")
      return "skips conditionally" if code =~ /^\s*skip\b.*\b(if|unless)\b/
      return "no assertions (comments or TODO only)" if assertion_kinds.empty?
      return "only assert true" if assertion_kinds.all?(:trivial)
      return "only asserts that something exists" if real_assertions.zero?

      nil
    end

    def preference
      tier = relative.start_with?("scarpe_examples/legacy/") ? 2 : (relative.start_with?("scarpe_examples/") ? 1 : 0)
      [-real_assertions, tier, relative]
    end
  end

  class Run
    def initialize(root)
      @root = File.expand_path(root)
      abort "no such directory: #{@root}" unless Dir.exist?(@root)
      @commit = `git -C #{@root} rev-parse --short HEAD 2>/dev/null`.strip
      @commit = nil if @commit.empty?
    end

    def call
      sources = Dir.glob(File.join(@root, "**", "*.sspec")).sort.map { |path| SourceCase.new(@root, path) }
      rejected, candidates = sources.partition(&:rejection)
      kept, duplicates = dedupe(candidates)
      unknown = RULINGS.keys - sources.map(&:relative)
      warn "RULINGS name source cases that do not exist: #{unknown.join(", ")}" if unknown.any?
      dropped, kept = kept.partition { |source| RULINGS.dig(source.relative, :drop) }

      reset_output
      written = kept.map { |source| write(source, duplicates.fetch(source.relative, [])) }
      write_manifest(sources.size, rejected, duplicates, dropped, written)
      report(sources.size, rejected, duplicates, dropped, written)
    end

    private

    def dedupe(candidates)
      duplicates = {}
      kept = candidates.group_by(&:app_key).values.map do |group|
        best, *others = group.sort_by(&:preference)
        duplicates[best.relative] = others.map(&:relative) if others.any?
        best
      end
      [kept.sort_by(&:relative), duplicates]
    end

    def reset_output
      Dir.glob(File.join(OUT, "*")).each { |entry| FileUtils.rm_rf(entry) }
      FileUtils.mkdir_p(OUT)
    end

    def write(source, duplicates)
      target = File.join(OUT, source.category, "#{source.name}.sspec")
      FileUtils.mkdir_p(File.dirname(target))
      test_code = RULINGS.dig(source.relative, :test) || source.test_code
      File.write(target, front_matter(source, duplicates) + "----------- app code\n" + source.app_code.sub(/\n*\z/, "\n") +
        "----------- test code\n" + test_code.sub(/\n*\z/, "\n"))
      [source.relative, target.delete_prefix(OUT + "/")]
    end

    def front_matter(source, duplicates)
      fields = { "source" => "cases/#{source.relative}", "source_commit" => @commit, "display" => RULINGS.dig(source.relative, :display) || "any" }
      fields["duplicates"] = duplicates.map { |path| "cases/#{path}" } if duplicates.any?
      if (ruling = RULINGS[source.relative]) && ruling[:expect]
        fields["expect"] = ruling[:expect]
        fields["reason"] = ruling[:reason]
      end
      comment = "# Imported from Noah Gibbs' Shoes-Spec corpus by spec/import_shoes_spec.rb.\n" \
        "# Change it through RULINGS or FIXES there: a re-import rewrites this file.\n"
      YAML.dump(fields.compact).sub("---\n", "---\n" + comment)
    end

    def write_manifest(total, rejected, duplicates, dropped, written)
      manifest = {
        "source_commit" => @commit,
        "counts" => {
          "source_cases" => total, "rejected" => rejected.size, "merged_duplicates" => duplicates.values.sum(&:size),
          "dropped_by_ruling" => dropped.size, "imported" => written.size,
        },
        "imported" => written.to_h,
        "duplicates" => duplicates,
        "dropped" => dropped.to_h { |source| [source.relative, RULINGS.dig(source.relative, :drop)] },
        "rejected" => rejected.to_h { |source| [source.relative, source.rejection] },
      }
      File.write(MANIFEST, "# Written by spec/import_shoes_spec.rb. Every source case and what became of it.\n" +
        YAML.dump(manifest))
    end

    def report(total, rejected, duplicates, dropped, written)
      puts "#{total} source cases from #{@root} (#{@commit || "no git"})"
      rejected.map(&:rejection).tally.sort_by { |_, count| -count }.each do |reason, count|
        puts format("  %4d rejected: %s", count, reason)
      end
      puts format("  %4d merged into a case with the same app code", duplicates.values.sum(&:size))
      puts format("  %4d dropped by ruling", dropped.size)
      puts format("  %4d imported into spec/shoes_spec/", written.size)
    end
  end
end

ShoesSpecImport::Run.new(ARGV.fetch(0) { abort "usage: ruby spec/import_shoes_spec.rb PATH/TO/shoes-spec/cases" }).call
