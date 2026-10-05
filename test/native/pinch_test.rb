# frozen_string_literal: true

require_relative "helper"

class PinchTest < Minitest::Test
  include NativeTestHelpers

  def test_slot_handlers_replace_and_remove_without_duplicate_callbacks
    skip_without_real_binary
    run = run_real(<<~'APP', test_code: <<~'TEST')
      Shoes.app(width: 400, height: 300) do
        @pane = stack(left: 20, top: 30, width: 200, height: 200, scroll: true) do
          stack(height: 1000) { para "A zoomable canvas" }
        end
      end
    APP
      app = Shoes.APPS.first
      pane = app.instance_variable_get(:@pane)
      driver = Scarpe::Native::Automation.new(Shoes::DisplayService.display_service)
      calls = []
      pane.on_pinch { flunk "the replaced handler must not run" }
      assert_same pane, pane.on_pinch { |*args| calls << args }
      driver.pinch(1.0, phase: :started, x: 100.25, y: 100.5)
      driver.pinch(1.1, x: 100.25, y: 100.5)
      driver.pinch(1.0, phase: :ended, x: 100.25, y: 100.5)
      assert_equal ["started", "moved", "ended"], calls.map { |call| call[1] }
      assert_equal [1.1, "moved", 80.25, 70.5], calls[1]
      assert_equal 0, pane.scroll_top
      pane.on_pinch
      driver.wheel(40, ctrl: true, x: 100.25, y: 100.5)
      assert_equal 40, pane.scroll_top
      assert_equal 3, calls.size
      pane.on_pinch { pane.remove }
      driver.pinch(1.0, phase: :started, x: 100.25, y: 100.5)
      driver.pinch(1.1, x: 100.25, y: 100.5)
      refute_includes driver.layout.map { |node| node[:id] }, pane.linkable_id
    TEST
    assert_spec_passed(run)
  end
end
