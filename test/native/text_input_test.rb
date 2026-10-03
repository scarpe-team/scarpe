# frozen_string_literal: true

require_relative "helper"

# Undo and redo in text fields reach the app as ordinary `change` events, so Lacci's
# edit_line text and the app's change block follow Cmd-Z (`:alt_z` by Shoes' name, Q5) and
# Control-Z. Real Lacci, real Rust child.
class TextInputTest < Minitest::Test
  include NativeTestHelpers

  def setup
    skip_without_real_binary
  end

  def test_edit_line_alignment_reaches_the_renderer_and_can_change
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @line = edit_line "hello", width: 240, align: "right"
      end
    APP
      line = edit_line
      assert_equal "right", line.align
      click_at 120, 14
      type_text "*"
      assert_equal "*hello", line.text, "the middle of the field is before the right-aligned word"
      line.obj.align = "left"
      wait_frames
      click_at 160, 14
      type_text "!"
      assert_equal "*hello!", line.text, "clicking past the left-aligned word inserts at its end"
      press_key :control_z
      assert_equal "*hello", line.text
    TEST
    assert_spec_passed(run)
  end

  def test_undo_and_redo_reach_the_app_as_changes
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @seen = para ""
        @line = edit_line { |line| @seen.replace("saw \#{line.text}") }
      end
    APP
      click_on edit_line
      type_text "hello"
      press_key :left
      press_key :end
      type_text " world"
      assert_equal "hello world", edit_line.text
      press_key :command_z
      assert_equal "hello", edit_line.text, "Cmd-Z takes back the last run of typing"
      assert_equal "saw hello", para.text, "and the app's change block sees it"
      press_key :control_z
      assert_equal "", edit_line.text, "Control-Z works too"
      press_key :command_shift_z
      assert_equal "hello", edit_line.text, "Cmd-Shift-Z puts it back"
    TEST
    assert_spec_passed(run)
  end

  # Keys Rust takes while Ruby is still in a slow change block leave Lacci's echoes trailing
  # behind them: an old echo must neither move the caret nor bring old text back (review).
  def test_typing_ahead_of_a_slow_change_block_keeps_every_key
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        $seen = []
        @line = edit_line("helo") { |line| sleep 0.05; $seen << line.text }
      end
    APP
      click_on edit_line
      press_key :end
      press_key :left
      child = Scarpe::Native::DisplayService.instance.child
      child.request(:type, text: "l") # both keys reach Rust before Ruby hears of either
      child.request(:type, text: "X")
      wait_frames # the slow block runs twice, and Lacci's two echoes follow the keys
      type_text "Y"
      assert_equal ["hello", "hellXo", "hellXYo"], $seen
      assert_equal "hellXYo", edit_line.text
      assert_equal "hellXYo", layout_tree.find { |node| node[:kind] == "EditLine" }[:text], "Y went in after the X"
    TEST
    assert_spec_passed(run)
  end

  def test_a_secret_field_copies_nothing
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @secret = edit_line secret: true
        @plain = edit_line
      end
    APP
      click_on edit_line("@secret")
      type_text "hunter2"
      press_key :control_a
      press_key :command_c
      click_on edit_line("@plain")
      press_key :command_v
      assert_equal "", edit_line("@plain").text, "nothing was on the clipboard to paste"
      assert_equal "hunter2", edit_line("@secret").text
      refute_includes layout_tree.map { |node| node[:text] }, "hunter2", "automation reads bullets"
    TEST
    assert_spec_passed(run)
  end
end
