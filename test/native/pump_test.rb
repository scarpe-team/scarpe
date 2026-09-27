# frozen_string_literal: true

require_relative "helper"

# An idle app sleeps (native/PERF.md): the pump waits for input instead of polling, and whatever
# needs it (Rust, a download thread, Ctrl-C) wakes it.
class PumpTest < Minitest::Test
  include NativeTestHelpers

  def test_a_post_from_another_thread_wakes_the_wait
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "script.json"), "[]")
      child = with_fake_child(dir) { Scarpe::Native::Child.new([FAKE_CHILD]) }
      child.version
      Thread.new { sleep 0.2; child.post(t: "props", id: 1, props: {}) }
      started = monotonic
      child.wait_for_input(5)
      assert_operator monotonic - started, :<, 1, "woken by the post, not the five second timeout"
    ensure
      child&.close
    end
  end

  def test_an_idle_app_hardly_wakes_up
    Dir.mktmpdir do |stats|
      script = [{ "on" => "run", "after" => 1.5, "emit" => [{ "t" => "closed", "app" => "first" }] }]
      run = run_app("Shoes.app { para 'Nothing moves' }\n", script: script, env: { "SCARPE_NATIVE_STATS" => stats })
      assert_clean_exit(run)
      steps = JSON.parse(File.read(File.join(stats, "ruby.json")))["phases"]["wait"]["n"]
      assert_operator steps, :<=, 6, "a second and a half of nothing (polling every 50 ms is 30 steps)"
    end
  end

  def test_ctrl_c_still_reaches_lacci_and_also_wakes_the_pump
    reached = []
    original = Signal.trap("INT") { reached << :lacci }
    child = Struct.new(:woken) { def wake! = self.woken += 1 }.new(0)
    Scarpe::Native::Pump.new(Struct.new(:child).new(child)).send(:wake_on_interrupt)
    ours = Signal.trap("INT", original)
    ours.call("INT")
    assert_equal [:lacci], reached
    assert_equal 1, child.woken
  ensure
    Signal.trap("INT", "DEFAULT")
  end

  def test_a_handler_that_takes_no_signal_argument_is_chained_too
    reached = []
    original = Signal.trap("INT", -> { reached << :lacci })
    child = Struct.new(:woken) { def wake! = self.woken += 1 }.new(0)
    Scarpe::Native::Pump.new(Struct.new(:child).new(child)).send(:wake_on_interrupt)
    ours = Signal.trap("INT", original)
    ours.call("INT")
    assert_equal [:lacci], reached
    assert_equal 1, child.woken
  ensure
    Signal.trap("INT", "DEFAULT")
  end

  private

  def with_fake_child(dir)
    saved = ENV.values_at("FAKE_CHILD_LOG", "FAKE_CHILD_SCRIPT")
    ENV["FAKE_CHILD_LOG"] = File.join(dir, "child.log")
    ENV["FAKE_CHILD_SCRIPT"] = File.join(dir, "script.json")
    yield
  ensure
    ENV["FAKE_CHILD_LOG"], ENV["FAKE_CHILD_SCRIPT"] = saved
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
