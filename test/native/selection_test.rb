# frozen_string_literal: true

require_relative "helper"

class SelectionTest < Minitest::Test
  include NativeTestHelpers

  def setup
    skip_without_real_binary unless name.start_with?("test_unit_")
  end

  def test_unit_an_older_renderer_without_the_query_returns_an_empty_string
    run = run_app(<<~APP, script: [
      Shoes.app do
        passage = para "A passage", selectable: true
        para passage.selected_text.inspect
      end
    APP
      { "on" => "run", "emit" => [{ "t" => "closed", "app" => "first" }] },
    ])
    assert_clean_exit(run)
    assert_equal ['""'], run.creates("Para").last.dig("props", "text_items")
    assert_equal 1, run.of_type("req").count { |message| message["op"] == "para_selection" }
  end

  def test_selected_text_reads_rich_text_and_flushes_pending_replacements
    run = run_real(<<~'APP', test_code: <<~'TEST')
      Shoes.app do
        @text = para "العِلْم ", strong("نورٌ"), "\ne\u0301 👩‍💻", selectable: true
        @other = para "Another paragraph", selectable: true
      end
    APP
      window = Shoes.APPS.first
      text = window.instance_variable_get(:@text)
      other = window.instance_variable_get(:@other)
      assert_equal "", text.selected_text
      text.focus
      wait_frames
      press_key :command_a
      assert_equal "العِلْم نورٌ\ne\u0301 👩‍💻", text.selected_text
      assert_equal "", other.selected_text
      text.replace("Next page")
      assert_equal "", text.selected_text
      text.remove
      assert_equal "", text.selected_text
    TEST
    assert_spec_passed(run)
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
