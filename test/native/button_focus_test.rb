# frozen_string_literal: true

require_relative "helper"

# Real Ruby callbacks and Rust focus routing, without opening a window.
class ButtonFocusTest < Minitest::Test
  include NativeTestHelpers

  def setup
    skip_without_real_binary
  end

  def test_button_focus_changes_reach_ruby_in_order
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app(width: 300, height: 240) do
        $focus_changes = []
        $clicks = []
        @close = button("Close", left: 10, top: 10) { |control| $clicks << control }
        @retry = button "Retry", left: 10, top: 50
        edit_line left: 10, top: 90
        [@close, @retry].each do |control|
          control.focus_changed = proc { |button, focused| $focus_changes << [button, focused] }
        end
      end
    APP
      close, retry_button = button("@close"), button("@retry")
      assert_empty $focus_changes
      click_on close
      assert_equal [[close.obj, true]], $focus_changes
      assert_equal [close.obj], $clicks, "focus notifications preserve the click callback"
      click_on close
      assert_equal [[close.obj, true]], $focus_changes, "no duplicate callback"
      $focus_changes.clear
      press_key :tab
      assert_equal [[close.obj, false], [retry_button.obj, true]], $focus_changes
      $focus_changes.clear
      press_key :shift_tab
      assert_equal [[retry_button.obj, false], [close.obj, true]], $focus_changes
      $focus_changes.clear
      retry_button.focus
      wait_frames
      assert_equal [[close.obj, false], [retry_button.obj, true]], $focus_changes
      $focus_changes.clear
      edit_line.focus
      wait_frames
      assert_equal [[retry_button.obj, false]], $focus_changes
      $focus_changes.clear
      close.focus
      wait_frames
      click_at 280, 220
      assert_equal [[close.obj, true], [close.obj, false]], $focus_changes
    TEST
    assert_spec_passed(run)
  end

  def test_button_focus_callback_can_be_replaced_and_removed
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        $focus_changes = []
        @button = button "Close"
        @button.focus_changed = proc { |control, focused| $focus_changes << [:original, control, focused] }
        edit_line
      end
    APP
      control = button
      control.focus
      wait_frames
      assert_equal [[:original, control.obj, true]], $focus_changes
      $focus_changes.clear
      control.obj.focus_changed = proc { |button, focused| $focus_changes << [:replacement, button, focused] }
      assert_empty $focus_changes, "installing a callback does not change focus"
      edit_line.focus
      wait_frames
      assert_equal [[:replacement, control.obj, false]], $focus_changes
      $focus_changes.clear
      control.obj.focus_changed = nil
      control.focus
      wait_frames
      edit_line.focus
      wait_frames
      assert_empty $focus_changes, "nil removes the callback for both gain and loss"
    TEST
    assert_spec_passed(run)
  end
end
