# frozen_string_literal: true

# Helpers for the native display service's Ruby tests (rake native_test).
#
# Unit tests load Lacci and the shim in-process. Integration tests run real apps through
# exe/scarpe --native in a subprocess: run_app puts test/native/fake_child.rb in the Rust binary's
# seat and reads back what it received, run_real uses the real binary. A fake osascript and a fake
# open on PATH record any call, so a builtin left unanswered or a link followed shows up as a
# failure instead of a dialog or a browser on someone's screen.

ENV["SCARPE_DISPLAY_SERVICE"] = "native"
ENV["SCARPE_NATIVE_LOG_LEVEL"] ||= "error"

require "json"
require "rbconfig"
require "tmpdir"
require "scarpe"
require "minitest/autorun"

module NativeTestHelpers
  ROOT = File.expand_path("../..", __dir__)
  SCARPE = File.join(ROOT, "exe", "scarpe")
  FAKE_CHILD = File.join(__dir__, "fake_child.rb")
  # Windows has no pgroup and signals no group; new_pgroup there, and taskkill /T for the tree.
  OWN_GROUP = Gem.win_platform? ? { new_pgroup: true } : { pgroup: true }

  def self.kill_group(pid)
    return system("taskkill", "/T", "/F", "/PID", pid.to_s, out: File::NULL, err: File::NULL) if Gem.win_platform?

    Process.kill("KILL", -pid)
  end

  # Tests of Unix signals, process groups and Shoes.run_program's own processes, none of which
  # Windows has (run_program runs in-process there).
  def skip_on_windows(why)
    skip "Windows: #{why}" if Gem.win_platform?
  end

  Run = Struct.new(:stdout, :stderr, :status, :timed_out, :received, :results, :osascript_calls, :open_calls, :child_argv, :dir, keyword_init: true) do
    def of_type(type)
      received.select { |message| message["t"] == type }
    end

    def creates(kind = nil)
      of_type("create").select { |message| kind.nil? || message["kind"] == kind }
    end

    def result
      results&.first
    end
  end

  # Runs app_code with exe/scarpe --native against the fake child. Optional test_code runs as a
  # Shoes-Spec; script is the fake child's rule list; argv builds the arguments after --native
  # from the app's path. Yields the scratch dir before running.
  def run_app(app_code, test_code: nil, script: [], env: {}, argv: ->(app) { [app] }, headless: true, timeout: 20)
    Dir.mktmpdir("scarpe-native-test") do |dir|
      app = File.join(dir, "app.rb")
      File.write(app, app_code)
      File.write(File.join(dir, "script.json"), JSON.generate(script))
      fake_commands(dir)
      yield dir if block_given?

      run_env = {
        "SCARPE_NATIVE_BIN" => FAKE_CHILD,
        "FAKE_CHILD_LOG" => File.join(dir, "child.log"),
        "FAKE_CHILD_ARGV" => File.join(dir, "argv.json"),
        "FAKE_CHILD_SCRIPT" => File.join(dir, "script.json"),
        "SCARPE_NATIVE_HEADLESS" => headless ? "1" : nil,
        "SCARPE_NATIVE_GHOST" => nil, # the fake child has no window; a test that means a ghost says so
        "SCARPE_NATIVE_SNAPSHOT_DIR" => File.join(dir, "snapshots"),
        "SCARPE_NATIVE_PID_FILE" => File.join(dir, "renderer.pid"),
        "SCARPE_NATIVE_LOG_LEVEL" => "warn",
        "LOCALAPPDATA" => dir,
        "PATH" => "#{File.join(dir, "bin")}#{File::PATH_SEPARATOR}#{ENV["PATH"]}",
      }
      if test_code
        File.write(File.join(dir, "test_code.rb"), test_code)
        run_env.merge!(
          "SHOES_SPEC_TEST" => File.join(dir, "test_code.rb"),
          "SHOES_MINITEST_EXPORT_FILE" => File.join(dir, "results.json"),
          "SHOES_MINITEST_CLASS_NAME" => "NativeSpec",
          "SHOES_MINITEST_METHOD_NAME" => "test_native",
        )
      end
      run_env.merge!(env)

      stdout, stderr, status, timed_out = capture(run_env, [RbConfig.ruby, SCARPE, "--dev", "--native", *argv.call(app)], timeout, dir)
      Run.new(
        stdout: stdout, stderr: stderr, status: status, timed_out: timed_out, dir: dir,
        received: read_json_lines(File.join(dir, "child.log")),
        results: (JSON.parse(File.read(File.join(dir, "results.json"))) if File.exist?(File.join(dir, "results.json"))),
        osascript_calls: File.exist?(File.join(dir, "osascript.log")) ? File.readlines(File.join(dir, "osascript.log")) : [],
        open_calls: File.exist?(File.join(dir, "open.log")) ? File.readlines(File.join(dir, "open.log")) : [],
        child_argv: (JSON.parse(File.read(File.join(dir, "argv.json"))) if File.exist?(File.join(dir, "argv.json"))),
      )
    end
  end

  # The real Rust child with bundled fonts, so pixels and rects are the same on every machine.
  # A window it opens (headless: false) is a ghost: real frames, but nobody sees it or can click
  # it, so a test run never covers someone's screen. SCARPE_NATIVE_GHOST=0 shows it.
  def run_real(app_code, env: {}, **options, &block)
    real_env = {
      "SCARPE_NATIVE_BIN" => NativeTestHelpers.real_binary, "SCARPE_NATIVE_ARGS" => "--fonts bundled",
      "SCARPE_NATIVE_GHOST" => ENV.fetch("SCARPE_NATIVE_GHOST", "1"),
    }
    run_app(app_code, env: real_env.merge(env), **options, &block)
  end

  # native/target/release/scarpe-native, rebuilt first when a crate source is newer than it
  # (DESIGN 5.2), so the tests never pass against yesterday's Rust. Nil without cargo or a build.
  def self.real_binary
    return @real_binary if defined?(@real_binary)

    @real_binary = Scarpe::Native::Binary.dev_binary
  rescue Scarpe::Native::ChildNotFound => e
    warn("Skipping the real-binary tests: #{e.message}")
    @real_binary = nil
  end

  def skip_without_real_binary
    skip "no scarpe-native binary (and no cargo to build one)" unless NativeTestHelpers.real_binary
  end

  def assert_clean_exit(run)
    refute run.timed_out, "app timed out\nstdout:\n#{run.stdout}\nstderr:\n#{run.stderr}"
    assert run.status.success?, "app exited #{run.status.exitstatus}\nstdout:\n#{run.stdout}\nstderr:\n#{run.stderr}"
    assert_empty run.osascript_calls, "a builtin fell through to osascript"
  end

  # A Shoes-Spec run passed: no failures, and at least one assertion ran.
  def assert_spec_passed(run)
    assert_clean_exit(run)
    refute_nil run.result, "no Shoes-Spec result was exported\nstderr:\n#{run.stderr}"
    failures = run.result["failures"].map { |failure| JSON.parse(failure[1])["m"] }
    assert_empty failures, "Shoes-Spec failed\nstderr:\n#{run.stderr}"
    assert_operator run.result["assertions"], :>, 0
  end

  # Sets environment variables (nil unsets) for the block, then puts them back.
  def with_env(vars)
    saved = vars.keys.to_h { |key| [key, ENV[key]] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| ENV[key] = value }
  end

  private

  def fake_commands(dir)
    bin = File.join(dir, "bin")
    Dir.mkdir(bin)
    %w[osascript open].each do |command|
      File.write(File.join(bin, command), "#!/bin/sh\necho \"$@\" >> \"#{dir}/#{command}.log\"\nexit 1\n")
      File.chmod(0o755, File.join(bin, command))
    end
  end

  def read_json_lines(path)
    File.exist?(path) ? File.readlines(path).map { |line| JSON.parse(line) } : []
  end

  def capture(env, command, timeout, dir)
    out_read, out_write = IO.pipe
    err_read, err_write = IO.pipe
    pid = Process.spawn(env, *command, out: out_write, err: err_write, in: File::NULL, chdir: dir, **OWN_GROUP)
    [out_write, err_write].each(&:close)
    readers = [out_read, err_read].map { |io| Thread.new { io.read } }

    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    timed_out = false
    until (status = Process.wait2(pid, Process::WNOHANG)&.last)
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        timed_out = true
        NativeTestHelpers.kill_group(pid)
        status = Process.wait2(pid).last
        break
      end
      sleep 0.02
    end
    [readers[0].value, readers[1].value.lines.grep_v(/Gem::Platform|previous definition/).join, status, timed_out]
  ensure
    kill_renderer(env["SCARPE_NATIVE_PID_FILE"])
  end

  # The renderer leads a process group of its own, out of reach of Ruby's; the shim leaves its pid
  # in the file until it has gone, so a file still there means Ruby died before stopping it.
  def kill_renderer(pid_file)
    NativeTestHelpers.kill_group(Integer(File.read(pid_file))) if pid_file && File.exist?(pid_file)
  rescue ArgumentError, SystemCallError
    nil
  end
end
