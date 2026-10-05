# frozen_string_literal: true

require_relative "helper"

class InertTest < Minitest::Test
  include NativeTestHelpers

  def setup
    skip_without_real_binary
  end

  def test_inert_subtrees_follow_ruby_setters_and_styles_and_preserve_content
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app(width: 400, height: 240) do
        @content = stack(width: 180, height: 180, inert: true) do
          @inner = stack(inert: false) do
            @field = edit_line "kept", width: 140
            @go = button("Behind") { @status.text = "pressed" }
          end
        end
        @dialog = button "Dialog", left: 220, top: 20
        @status = para "ready", left: 220, top: 80
      end
    APP
      content = stack("@content")
      field = edit_line("@field")
      behind = button("@go")
      visible = ->(drawable) { a11y_nodes.any? { |node| node[:id] == drawable.linkable_id } }
      assert content.inert
      refute visible.call(field)
      before = layout_of(behind).to_a
      x, y, width, height = before
      click_at(x + width / 2, y + height / 2)
      assert_equal "ready", para("@status").text
      press_key :tab
      assert_equal button("@dialog").linkable_id, focused_drawable.linkable_id

      content.inert = false
      wait_frames
      assert visible.call(field)
      assert_equal before, layout_of(behind).to_a
      click_on behind
      assert_equal "pressed", para("@status").text
      field.focus
      wait_frames
      content.style(inert: true)
      wait_frames
      assert_nil focused_drawable
      type_text "ignored"
      assert_equal "kept", field.text
      content.style(inert: nil)
      wait_frames
      assert_nil focused_drawable, "restoring content does not restore focus automatically"
      assert visible.call(field)
      field.focus
      wait_frames
      assert_equal field.linkable_id, focused_drawable.linkable_id
    TEST
    assert_spec_passed(run)
  end
end
