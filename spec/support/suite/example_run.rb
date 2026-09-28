# frozen_string_literal: true

module SpecSuite
  # Smoke-runs one example from spec/examples.yml.
  #
  # niente: the example must load without a Ruby error and either keep running for `wait`
  #         seconds or exit 0 on its own. Niente draws nothing, so this proves Lacci only.
  # native: `scarpe peek EXAMPLE --wait W --shot gallery/<slug>.png` (DESIGN 8), then no Ruby
  #         error, no Rust panic, a snapshot that is not one flat colour, and the colours its
  #         examples.yml `pixels:` name.
  class ExampleRun
    DEFAULT_WAIT = { "niente" => 3.0, "native" => 1.5 }.freeze
    PEEK_ALLOWANCE = 30
    LOGGED_ERROR = /\A\S+ error: /
    # A line logged at warn level is a warning even when it names an exception it survived
    # ("Normalize warn: Could not download ...: OpenSSL::SSL::SSLError").
    NOT_AN_ERROR = /warning:|\S warn: |SignalException|SIGTERM/

    def initialize(example, display:, tree:, sandboxes:, wait: nil, include_skipped: false, keep: false)
      @example = example
      @display = display
      @tree = tree
      @sandboxes = sandboxes
      @wait = wait || example.wait || DEFAULT_WAIT.fetch(display)
      @include_skipped = include_skipped
      @keep = keep
    end

    def call
      expected = @example.status_on(@display)
      return row("skip", @example.reason || "status: skip") if expected == "skip" && !@include_skipped

      sandbox = Sandbox.new(@sandboxes, @example.slug)
      @env = sandbox.env(@display, dialog_stubs)
      status, message, secs = @display == "native" ? peek(sandbox) : load_under_niente(sandbox)
      status, message = apply_expectation(expected, status, message)
      row(status, message, secs:, blocked: sandbox.trapped_commands.first(3), sandbox: (sandbox.root if @keep))
    ensure
      sandbox&.remove unless @keep
    end

    def self.gallery_dir = File.join(RESULTS_DIR, "gallery")

    private

    def file = @tree.example_path(@example.path)

    def load_under_niente(sandbox)
      finished = Child.run([RbConfig.ruby, SCARPE_EXE, "--dev", file], env: @env, chdir: File.dirname(file),
        log: sandbox.log, deadline_after: @wait)
      error = first_error(finished.output)
      verdict =
        if error then ["fail", finished.timed_out ? "loaded, but logged: #{error}" : "exit #{finished.exitstatus}: #{error}"]
        elsif finished.timed_out then ["pass", "still running after #{@wait}s"]
        elsif finished.exitstatus == 0 then ["pass", "exited 0 after #{finished.secs}s"]
        else ["fail", "exit #{finished.exitstatus || "by signal #{finished.termsig}"}#{last_line(finished.output)}"]
        end
      [*verdict, finished.secs]
    end

    def peek(sandbox)
      shot = File.join(self.class.gallery_dir, "#{@example.slug}.png")
      FileUtils.mkdir_p(File.dirname(shot))
      FileUtils.rm_f(shot)
      argv = [RbConfig.ruby, SCARPE_EXE, "--dev", "peek", file, "--wait", @wait.to_s, *step_args, "--shot", shot]
      finished = Child.run(argv, env: @env, chdir: File.dirname(file), log: sandbox.log,
        deadline_after: @wait + PEEK_ALLOWANCE)
      [*judge_peek(finished, shot), finished.secs]
    end

    def judge_peek(finished, shot)
      output = finished.output
      return ["timeout", "peek did not finish within #{@wait + PEEK_ALLOWANCE}s"] if finished.timed_out
      if (panic = output.lines.find { |line| line.include?("panicked at") })
        return ["fail", "Rust panic: #{panic.strip[0, 300]}"]
      end
      return ["fail", "Ruby error: #{first_error(output)}"] if first_error(output)
      return ["fail", "peek exited #{finished.exitstatus}#{last_line(output)}"] unless finished.exitstatus == 0
      return ["fail", "peek wrote no snapshot"] unless File.size?(shot)

      png = Png.read(shot)
      flat = png.flat_color
      return ["fail", "blank snapshot: every pixel is #{flat}"] if flat

      wrong = wrong_pixel(png)
      wrong ? ["fail", wrong] : ["pass", SpecSuite.relative(shot)]
    rescue Png::Unsupported => e
      ["fail", "unreadable snapshot: #{e.message}"]
    end

    # The first of the example's `pixels:` the snapshot does not show, as a message, or nil.
    def wrong_pixel(png)
      @example.pixels.each do |x, y, want|
        got = "#" + png.pixel(x, y).first(3).map { |channel| format("%02x", channel) }.join
        return "pixel #{x},#{y} is #{got}, not #{want.downcase}" unless got == want.downcase
      end
      nil
    end

    def step_args
      @example.steps.flat_map do |step|
        step.flat_map do |kind, value|
          case kind.to_s
          when "click" then ["--click", value.to_s]
          when "click_at" then ["--click-at", Array(value).join(",")]
          when "drag" then ["--drag", Array(value).flatten.join(",")]
          when "type" then ["--type", value.to_s]
          when "key" then ["--key", value.to_s]
          when "wait" then ["--wait", value.to_s]
          else raise ArgumentError, "#{@example.path}: unknown peek step #{kind.inspect}"
          end
        end
      end
    end

    # examples.yml `dialogs:` answer the example's dialogs the way a case's front matter does,
    # so an app that asks before it draws (confirm, ask_color) shows what it draws.
    def dialog_stubs
      @example.dialogs ? { "SPEC_DIALOG_STUBS" => JSON.generate(@example.dialogs) } : {}
    end

    def apply_expectation(expected, status, message)
      return [status, message] unless expected == "fails"

      case status
      when "fail", "error" then ["expected_fail", message]
      when "pass" then ["unexpected_pass", "loaded cleanly, but examples.yml says fails (#{@example.reason})"]
      else [status, message]
      end
    end

    def first_error(output)
      line = output.lines.find do |text|
        (text =~ CaseRun::ERROR_LINE || text =~ LOGGED_ERROR) && text !~ NOT_AN_ERROR
      end
      line && SpecSuite.tidy(line.strip, @tree.root)[0, 300]
    end

    def last_line(output)
      last = output.lines.map(&:strip).reject(&:empty?).last
      last ? ": #{last[0, 200]}" : ""
    end

    def row(status, message, secs: nil, blocked: [], sandbox: nil)
      {
        "path" => @example.path,
        "status" => status,
        "message" => message,
        "secs" => secs,
        "blocked" => (blocked unless blocked.empty?),
        "sandbox" => sandbox,
      }.compact
    end
  end

  # A private copy of examples/ (plus docs/static, which shoes-contrib examples reach through
  # __dir__), so examples that write next to themselves write into the copy.
  class ExampleTree
    attr_reader :root

    def initialize(parent)
      @root = File.join(parent, "repo")
      FileUtils.mkdir_p(File.join(root, "docs"))
      FileUtils.cp_r(File.join(REPO, "examples"), root)
      FileUtils.cp_r(File.join(REPO, "docs", "static"), File.join(root, "docs"))
    end

    def example_path(path)
      File.join(root, path)
    end
  end
end
