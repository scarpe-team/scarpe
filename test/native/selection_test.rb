# frozen_string_literal: true

require_relative "helper"

class SelectionTest < Minitest::Test
  include NativeTestHelpers

  def setup
    skip_without_real_binary
  end

  def test_a_selectable_rich_paragraph_can_be_focused_from_ruby_and_copied
    run = run_real(<<~'APP', test_code: <<~'TEST')
      Shoes.app do
        @text = para "العِلْم ", strong("نورٌ"), " — e\u0301", selectable: true
        @field = edit_line
      end
    APP
      para.focus
      wait_frames
      assert_equal para.linkable_id, focused_drawable.linkable_id
      press_key :command_a
      press_key :command_c
      press_key :backspace
      type_text "ignored"
      assert_equal "العِلْم نورٌ — e\u0301", para.text
      press_key :tab
      press_key :command_v
      assert_equal para.text, edit_line.text
      para.selectable = false
      press_key :shift_tab
      assert_equal edit_line.linkable_id, focused_drawable.linkable_id
    TEST
    assert_spec_passed(run)
  end
end
