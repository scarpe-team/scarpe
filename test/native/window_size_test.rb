# frozen_string_literal: true

require_relative "helper"

class WindowSizeTest < Minitest::Test
  include NativeTestHelpers

  def test_minimum_options_and_changes_reach_the_renderer
    run = run_app(<<~APP, script: [{ "on" => "run", "emit" => [{ "t" => "closed", "app" => "first" }] }])
      Shoes.app(min_width: 800, min_height: 600) do
        self.min_width = 900
        self.min_height = nil
      end
    APP
    assert_clean_exit(run)
    app = run.creates("App").first
    assert_equal({ "min_width" => 800, "min_height" => 600 }, app["props"].slice("min_width", "min_height"))
    assert_equal [{ "min_width" => 900 }, { "min_height" => nil }], run.of_type("props").map { |m| m["props"] }
  end

  def test_minimums_are_absent_by_default
    run = run_app(<<~APP, script: [{ "on" => "run", "emit" => [{ "t" => "closed", "app" => "first" }] }])
      Shoes.app { para "Default size" }
    APP
    assert_clean_exit(run)
    assert_empty run.creates("App").first["props"].slice("min_width", "min_height")
  end

  def test_ruby_sees_the_constrained_size_and_can_remove_the_limits
    skip_without_real_binary
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app(width: 320, height: 240, min_width: 800, min_height: 600) { para "Reader" }
    APP
      app = Shoes.APPS.first
      assert_equal [800, 600], [app.width, app.height]
      resize_window(1000, 720)
      app.style(min_width: 850, min_height: 650)
      layout_tree
      assert_equal [1000, 720], [app.width, app.height]
      app.min_height = 800
      layout_tree
      assert_equal [1000, 800], [app.width, app.height]
      app.style(width: 320, height: 240)
      layout_tree
      assert_equal [850, 800], [app.width, app.height]
      app.style(min_width: nil, min_height: nil)
      layout_tree
      assert_equal [850, 800], [app.width, app.height]
      resize_window(320, 240)
      assert_equal [320, 240], [app.width, app.height]
    TEST
    assert_spec_passed(run)
  end
end
