# frozen_string_literal: true

module SpecSuite
  # Runs one CaseFile on one display and returns its result row.
  #
  # The app code and test code go into separate files in a sandbox and run as
  # `ruby exe/scarpe --dev app.rb` with SHOES_SPEC_TEST pointing at the test file, which is
  # how every Shoes-Spec runner drives a display (research 04, A3). Running the .sspec in
  # place would chdir into spec/ and let the app write into the repo.
  class CaseRun
    DEFAULT_TIMEOUT = { "niente" => 20, "native" => 40 }.freeze
    # An exception class, a common NameError/ArgumentError phrase, a Rust panic, or Ruby's own
    # "file:1:in 'm': message (Scarpe::Native::ChildDied)" line for any uncaught exception.
    ERROR_LINE = /\b(?:[A-Z]\w*(?:::\w+)*(?:Error|Exception)\b|undefined (?:local variable or )?method|
      uninitialized constant|wrong number of arguments|panicked at)|:\d+:in .*\([A-Z]\w*(?:::\w+)*\)\s*\z/x
    # Lacci's changelog runs `git rev-parse HEAD` in the sandbox cwd; Bundler warns about constants.
    NOISE = /warning:|\Afatal: not a git repository/

    def initialize(case_file, display:, sandboxes:, timeout: nil, keep: false)
      @case = case_file
      @display = display
      @sandboxes = sandboxes
      @timeout = case_file.valid? && case_file.timeout || timeout || DEFAULT_TIMEOUT.fetch(display)
      @keep = keep
    end

    def call
      return row("not_applicable", "display: #{@case.scope} case") unless @case.runs_on?(@display)
      return row("error", "invalid case: #{@case.problems.join("; ")}") unless @case.valid?

      sandbox = Sandbox.new(@sandboxes, Sandbox.dir_name(@case.relative_path))
      status, message, extra = run_in(sandbox)
      status, message = apply_expectation(status, message)
      row(status, message, **extra, sandbox: (sandbox.root if @keep))
    ensure
      sandbox&.remove unless @keep
    end

    private

    def run_in(sandbox)
      sandbox.copy_assets
      app = sandbox.write("app.rb", @case.app_code)
      test = sandbox.write("test.rb", @case.test_code)
      result_json = File.join(sandbox.root, "result.json")
      env = sandbox.env(@display,
        "SHOES_SPEC_TEST" => test,
        "SHOES_MINITEST_EXPORT_FILE" => result_json,
        "SHOES_MINITEST_CLASS_NAME" => test_class_name,
        "SHOES_MINITEST_METHOD_NAME" => test_method_name,
        "SPEC_DIALOG_STUBS" => (JSON.generate(@case.dialog_stubs) if @case.dialog_stubs))
      finished = Child.run([RbConfig.ruby, SCARPE_EXE, "--dev", app], env:, chdir: sandbox.work, log: sandbox.log,
        deadline_after: @timeout)
      outcome = MinitestOutcome.read(result_json)

      status, message = classify(finished, outcome, sandbox)
      [status, message, { secs: finished.secs, assertions: outcome&.assertions }]
    end

    def classify(finished, outcome, sandbox)
      dialog = sandbox.trapped_commands.grep(/\Aosascript/).first
      return ["error", "tried to open a real OS dialog: #{dialog[0, 120]}"] if dialog
      return ["timeout", "no result after #{@timeout}s#{tail_note(finished)}"] if finished.timed_out && !outcome
      return [outcome.status, with_location(outcome, sandbox)] if outcome

      ["error", readable(no_result_message(finished), sandbox)]
    end

    def apply_expectation(status, message)
      return [status, message] unless @case.expectation(@display) == "fail"

      case status
      when "fail", "error" then ["expected_fail", message]
      when "pass" then ["unexpected_pass", "passed, but front matter says expect: fail (#{@case.reason})"]
      else [status, message]
      end
    end

    def with_location(outcome, sandbox)
      return outcome.message if outcome.status == "pass"

      frame = outcome.backtrace.find { |line| line.start_with?(sandbox.work + "/") }
      match = frame&.match(%r{/(app|test)\.rb:(\d+)})
      message = SpecSuite.tidy(outcome.message)
      return message unless match

      line = @case.line_in_file(match[1] == "app" ? :app : :test, match[2].to_i)
      "#{message} (#{@case.relative_path}:#{line})"
    end

    def no_result_message(finished)
      error = finished.output.lines.find { |line| line =~ ERROR_LINE && line !~ NOISE }
      exit_note = finished.termsig ? "killed by signal #{finished.termsig}" : "exit #{finished.exitstatus}"
      return "no result (#{exit_note}): #{error.strip}" if error
      return "no result (exit 0): the test code never ran; does the app call Shoes.app?#{tail_note(finished)}" if finished.exitstatus == 0

      "no result (#{exit_note})#{tail_note(finished)}"
    end

    def tail_note(finished)
      last = finished.output.lines.map(&:strip).reject { |line| line.empty? || line =~ NOISE }.last
      last ? "; last output: #{last[0, 200]}" : ""
    end

    # "/tmp/.../work/app.rb:3:in 'block'" becomes "manual/x/y.sspec:7:in 'block'".
    def readable(message, sandbox)
      mapped = message.gsub(%r{#{Regexp.escape(sandbox.work)}/(app|test)\.rb:(\d+)}) do
        "#{@case.relative_path}:#{@case.line_in_file(::Regexp.last_match(1) == "app" ? :app : :test, ::Regexp.last_match(2).to_i)}"
      end
      SpecSuite.tidy(mapped)[0, 400]
    end

    def row(status, message = nil, secs: nil, assertions: nil, sandbox: nil)
      {
        "path" => @case.relative_path,
        "status" => status,
        "message" => message,
        "secs" => secs,
        "assertions" => assertions,
        "manual" => @case.front_matter&.fetch("manual", nil),
        "testability" => @case.front_matter&.fetch("testability", nil),
        "scope" => @case.valid? ? @case.scope : nil,
        "sandbox" => sandbox,
      }.compact
    end

    # Object.const_set needs a valid constant; "manual/_examples" becomes "SpecManualExamples".
    # The Spec prefix keeps a directory called "shoes" from ever replacing the Shoes class.
    def test_class_name
      "spec_#{@case.directory}".gsub(/[^A-Za-z0-9_]+/, "_")
    end

    def test_method_name
      "test_#{@case.name.gsub(/[^A-Za-z0-9_]+/, "_")}"
    end
  end
end
