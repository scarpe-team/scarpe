# frozen_string_literal: true

$LOAD_PATH.unshift File.join(SpecSuite::REPO, "scarpe-components", "lib")
module Scarpe; end
require "scarpe/components/errors"
require "scarpe/components/segmented_file_loader"

module SpecSuite
  # One .sspec file: front matter, app code, test code, and everything wrong with them.
  # Parsing goes through Lacci's own SegmentedFileLoader so a case splits here exactly as it
  # would under `scarpe app.sspec`, quirks included (any line of 5+ dashes is a divider).
  class CaseFile
    TESTABILITIES = %w[api visual interactive dialog].freeze
    SCOPES = %w[any native].freeze
    EXPECTATIONS = %w[pass fail].freeze
    MANUAL_KEYS = %w[manual lines testability display ledger].freeze
    IMPORT_KEYS = %w[source source_commit duplicates].freeze
    COMMON_KEYS = %w[display testability expect reason timeout dialogs].freeze

    attr_reader :path, :front_matter, :app_code, :test_code, :problems

    def initialize(path)
      @path = File.expand_path(path)
      @problems = []
      parse
      lint if @problems.empty?
    end

    def relative_path
      SpecSuite.relative(path)
    end

    def directory
      File.dirname(relative_path)
    end

    def name
      File.basename(path, ".sspec")
    end

    def valid?
      problems.empty?
    end

    def manual_case?
      relative_path.start_with?("manual/")
    end

    def scope
      front_matter.fetch("display", "any")
    end

    def runs_on?(display)
      scope == "any" || scope == display
    end

    # "pass" or "fail". `expect:` is either one word for every display, or a Hash by display.
    def expectation(display)
      expect = front_matter["expect"]
      expect = expect[display] if expect.is_a?(Hash)
      expect || "pass"
    end

    def reason
      front_matter["reason"]
    end

    def timeout
      front_matter["timeout"]
    end

    def dialog_stubs
      front_matter["dialogs"]
    end

    # Maps "app.rb:3" / "test.rb:3" in a child's output back to lines of this file.
    def line_in_file(segment, line)
      offset = segment == :app ? @app_offset : @test_offset
      offset && offset + line
    end

    private

    def parse
      contents = File.read(path)
      @front_matter, segments = Scarpe::Components::SegmentedFileLoader.front_matter_and_segments_from_file(contents)
      @front_matter = stringify(@front_matter || {})
      if segments.size != 2
        @problems << "needs exactly two segments ('----------- app code' and '----------- test code'), found #{segments.size}"
        return
      end

      @app_code, @test_code = segments.values
      @app_offset = line_offset(contents, @app_code)
      @test_offset = line_offset(contents, @test_code)
    rescue StandardError, Psych::Exception => e
      @front_matter ||= {}
      @problems << "cannot parse: #{e.class}: #{e.message.lines.first&.strip}"
    end

    def stringify(hash)
      hash.is_a?(Hash) ? hash.to_h { |key, value| [key.to_s, value] } : { "front matter" => hash }
    end

    def line_offset(contents, segment)
      index = contents.rindex(segment)
      index && contents[0...index].count("\n")
    end

    def lint
      unknown = front_matter.keys - COMMON_KEYS - MANUAL_KEYS - IMPORT_KEYS
      problems << "unknown front matter keys: #{unknown.join(", ")}" if unknown.any?
      lint_manual_reference if manual_case?
      lint_values
      lint_test_code
    end

    def lint_manual_reference
      %w[manual lines testability display].each do |key|
        problems << "front matter needs #{key}:" unless front_matter.key?(key)
      end
      if (id = front_matter["manual"]) && !ManualIndex.id?(id)
        problems << "manual: #{id.inspect} is not an id in native/research/manual_inventory.json"
      end
      lines = front_matter["lines"]
      return unless front_matter.key?("lines")

      unless lines.is_a?(Array) && lines.size == 2 && lines.all?(Integer) && lines[0] <= lines[1] &&
          lines[0] >= 1 && lines[1] <= ManualIndex.line_count
        problems << "lines: must be [first, last] line numbers of docs/static/manual.md (1..#{ManualIndex.line_count})"
      end
    end

    def lint_values
      check_enum("testability", TESTABILITIES)
      check_enum("display", SCOPES)
      expect = front_matter["expect"]
      values = expect.is_a?(Hash) ? expect.values : [expect].compact
      if expect.is_a?(Hash) && (expect.keys - DISPLAYS).any?
        problems << "expect: keys must be display names (#{DISPLAYS.join(", ")})"
      end
      problems << "expect: must be pass or fail" unless (values - EXPECTATIONS).empty?
      problems << "expect: fail needs a reason:" if values.include?("fail") && reason.to_s.strip.empty?
      problems << "timeout: must be a number of seconds" if timeout && !timeout.is_a?(Numeric)
      lint_dialogs
    end

    def check_enum(key, allowed)
      value = front_matter[key]
      problems << "#{key}: must be one of #{allowed.join(", ")}" if front_matter.key?(key) && !allowed.include?(value)
    end

    def lint_dialogs
      return unless front_matter.key?("dialogs")

      stubs = dialog_stubs
      kinds = %w[alert confirm ask ask_color ask_open_file ask_save_file ask_open_folder ask_save_folder]
      unless stubs.is_a?(Hash) && (stubs.keys.map(&:to_s) - kinds).empty?
        problems << "dialogs: must map dialog kinds (#{kinds.join(", ")}) to answers"
      end
    end

    def lint_test_code
      code = test_code.gsub(/#.*$/, "")
      problems << "test code is empty" if code.strip.empty?
      problems << "test code uses dom_html, which only the webview display has" if code.include?("dom_html")
    end
  end

  module ManualIndex
    class << self
      def id?(id)
        ids.include?(id)
      end

      def line_count
        @line_count ||= File.foreach(MANUAL).count
      end

      def entry(id)
        entries[id]
      end

      private

      def ids
        entries.keys
      end

      def entries
        @entries ||= JSON.parse(File.read(MANUAL_INVENTORY)).to_h { |entry| [entry["id"], entry] }
      end
    end
  end
end
