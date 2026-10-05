# frozen_string_literal: true

require_relative "helper"

class ReducedMotionTest < Minitest::Test
  include NativeTestHelpers

  def test_queries_are_fresh_and_renderer_errors_have_a_false_fallback
    replies = [{ "value" => true }, { "value" => false }, { "value" => true, "error" => "unsupported" }, {}, { "value" => "true" }]
    calls = []
    child = Object.new
    child.define_singleton_method(:request) { |op| calls << op; replies.shift }
    service = Struct.new(:child).new(child)
    builtins = Scarpe::Native::Builtins.new(service, interactive: false)
    assert_equal [true, false, false, false, false], 5.times.map { builtins.answer("reduced_motion", []) }
    assert_equal [:reduced_motion] * 5, calls, "each call queries again, including headless apps"
    assert_empty builtins.seen, "a preference query is not a dialog"
  end

  def test_the_ruby_builtin_reaches_the_renderer_before_a_window_runs
    run = run_app(<<~'APP', script: [
      Shoes.app { para reduced_motion?.to_s }
    APP
      { "on" => "req:reduced_motion", "reply" => true },
      { "on" => "run", "emit" => [{ "t" => "closed", "app" => "first" }] },
    ])
    assert_clean_exit(run)
    assert_equal ["true"], run.creates("Para").first.dig("props", "text_items")
    assert_equal 1, run.of_type("req").count { |message| message["op"] == "reduced_motion" }
    assert_operator run.received.index { |message| message["op"] == "reduced_motion" }, :<,
      run.received.index { |message| message["t"] == "run" }
  end

  def test_the_real_renderer_answers_headlessly_without_changing_os_settings
    skip_without_real_binary
    run = run_real(<<~'APP', test_code: <<~'TEST')
      $before_app = reduced_motion?
      Shoes.app { @preference = reduced_motion? }
    APP
      assert_includes [true, false], $before_app
      value = Shoes.APPS.first.instance_variable_get(:@preference)
      assert_includes [true, false], value
      assert_equal false, value if RUBY_PLATFORM.include?("linux")
    TEST
    assert_spec_passed(run)
  end
end
