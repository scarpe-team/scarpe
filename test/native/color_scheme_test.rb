# frozen_string_literal: true

require_relative "helper"

class ColorSchemeTest < Minitest::Test
  include NativeTestHelpers

  def test_queries_are_fresh_and_unknown_or_failed_replies_return_nil
    replies = [{ "value" => "dark" }, { "value" => "light" }, { "value" => nil },
      { "value" => "dark", "error" => "unavailable" }, { "value" => "unexpected" }, {}]
    calls = []
    child = Object.new
    child.define_singleton_method(:request) { |op| calls << op; replies.shift }
    builtins = Scarpe::Native::Builtins.new(Struct.new(:child).new(child), interactive: false)
    assert_equal ["dark", "light", nil, nil, nil, nil], 6.times.map { builtins.answer("preferred_color_scheme", []) }
    assert_equal [:preferred_color_scheme] * 6, calls
    assert_empty builtins.seen, "preference reads are not dialogs"
  end

  def test_the_public_query_returns_symbols_before_the_native_window_runs
    run = run_app(<<~APP, script: [
      Shoes.app { para preferred_color_scheme.inspect }
    APP
      { "on" => "req:preferred_color_scheme", "reply" => "dark" },
      { "on" => "run", "emit" => [{ "t" => "closed", "app" => "first" }] },
    ])
    assert_clean_exit(run)
    assert_equal [":dark"], run.creates("Para").first.dig("props", "text_items")
    assert_operator run.received.index { |m| m["op"] == "preferred_color_scheme" }, :<,
      run.received.index { |m| m["t"] == "run" }
  end

  def test_real_headless_queries_need_no_window_or_preference_changes
    skip_without_real_binary
    run = run_real(<<~APP, test_code: <<~TEST)
      $before_display = preferred_color_scheme
      Shoes.app { @scheme = preferred_color_scheme }
    APP
      assert_nil $before_display
      assert_includes [:light, :dark, nil], Shoes.APPS.first.instance_variable_get(:@scheme)
    TEST
    assert_spec_passed(run)
  end
end
