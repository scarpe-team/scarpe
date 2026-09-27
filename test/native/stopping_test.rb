# frozen_string_literal: true

require_relative "helper"

# However Ruby stops, the renderer goes with it. The child sits in a process group of its own
# (so a terminal's Ctrl-C reaches only Ruby), which signals to Ruby's group never reach.
class StoppingTest < Minitest::Test
  include NativeTestHelpers

  def setup
    @dir = Dir.mktmpdir("scarpe-native-stopping")
  end

  def teardown
    [@child, @ruby].compact.each { |pid| signal("KILL", pid) }
    Process.wait(@ruby) if @ruby
    FileUtils.rm_rf(@dir)
  end

  # A child stuck in layout never reads the EOF that says Ruby is gone, and a harness that
  # follows TERM with KILL (spec/run waits 1 s) never waits out at_exit's 2 s grace (review).
  def test_term_takes_a_stuck_child_down_at_once
    start_app(script: [{ "on" => "run", "hang" => true }])
    wait_until { child_log.include?('"t":"run"') }

    signal("TERM", @ruby)
    sleep 0.5
    signal("KILL", -@ruby) # what the harness does next
    Process.wait(@ruby)
    @ruby = nil

    assert wait_until { gone?(@child) }, "the stuck child outlived Ruby"
  end

  # A harness that has to kill Ruby finds the child through SCARPE_NATIVE_PID_FILE, which names
  # it for exactly as long as it runs.
  def test_the_pid_file_names_the_child_until_it_is_gone
    pid_file = File.join(@dir, "renderer.pid")
    run = run_app(<<~RUBY, script: [{ "on" => "run", "emit" => [{ "t" => "closed", "app" => "first" }] }], env: { "SCARPE_NATIVE_PID_FILE" => pid_file, "FAKE_CHILD_PID" => File.join(@dir, "child.pid") })
      Shoes.app { puts File.read(ENV["SCARPE_NATIVE_PID_FILE"]) }
    RUBY
    assert_clean_exit(run)
    assert_equal File.read(File.join(@dir, "child.pid")), run.stdout.strip, "the child's pid while it ran"
    refute File.exist?(pid_file), "and no file once it had gone"
  end

  private

  def start_app(script:)
    File.write(File.join(@dir, "app.rb"), "Shoes.app { para 'hi' }\n")
    File.write(File.join(@dir, "script.json"), JSON.generate(script))
    env = {
      "SCARPE_NATIVE_BIN" => FAKE_CHILD, "SCARPE_NATIVE_HEADLESS" => "1", "SCARPE_NATIVE_GHOST" => nil,
      "SCARPE_NATIVE_LOG_LEVEL" => "error", "FAKE_CHILD_SCRIPT" => File.join(@dir, "script.json"),
      "FAKE_CHILD_LOG" => File.join(@dir, "child.log"), "FAKE_CHILD_PID" => File.join(@dir, "child.pid"),
    }
    @ruby = Process.spawn(env, RbConfig.ruby, SCARPE, "--dev", "--native", "app.rb", chdir: @dir, pgroup: true,
      in: File::NULL, out: File::NULL, err: File::NULL)
    wait_until { File.exist?(File.join(@dir, "child.pid")) }
    @child = Integer(File.read(File.join(@dir, "child.pid")))
  end

  def child_log
    File.exist?(File.join(@dir, "child.log")) ? File.read(File.join(@dir, "child.log")) : ""
  end

  # A group whose leader has exited but is not yet reaped answers EPERM on macOS.
  def signal(name, pid)
    Process.kill(name, pid)
  rescue Errno::ESRCH, Errno::EPERM
    nil
  end

  def gone?(pid)
    Process.kill(0, pid)
    false
  rescue Errno::ESRCH
    true
  end

  def wait_until(seconds = 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    until (done = yield)
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.02
    end
    done
  end
end
