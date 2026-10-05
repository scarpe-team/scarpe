# frozen_string_literal: true

require_relative "helper"

class OpacityTest < Minitest::Test
  include NativeTestHelpers

  def setup
    skip_without_real_binary
  end

  def test_slot_opacity_composites_children_and_follows_ruby_updates
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app(width: 200, height: 120) do
        @panel = stack(left: 10, top: 10, width: 100, height: 70, opacity: 0.5) do
          background red
          @square = rect(left: 20, top: 10, width: 50, height: 40, fill: blue, strokewidth: 0)
        end
      end
    APP
      panel = stack("@panel")
      geometry = layout_of(panel).to_a
      assert_pixel = ->(expected) { expected.zip(pixel_at(40, 30)).each { |wanted, actual| assert_in_delta wanted, actual, 1 } }
      assert_pixel.call([127, 127, 255, 255])
      panel.opacity = 0
      wait_frames
      assert_equal [255, 255, 255, 255], pixel_at(40, 30)
      panel.style(opacity: nil)
      wait_frames
      assert_equal [0, 0, 255, 255], pixel_at(40, 30)
      rect("@square").opacity = 0.5
      wait_frames
      assert_pixel.call([127, 0, 128, 255])
      assert_equal geometry, layout_of(panel).to_a
    TEST
    assert_spec_passed(run)
  end

  def test_opacity_keeps_the_control_focus_and_handlers
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @panel = stack(opacity: 0) do
          @name = edit_line "Book"
          @save = button("Save") { @status.text = "saved" }
        end
        @status = para "ready"
      end
    APP
      a11y_action edit_line("@name"), :focus
      type_text "Updated"
      text = edit_line("@name").text
      a11y_action button("@save"), :click
      assert_equal "saved", para("@status").text
      stack("@panel").opacity = 1
      wait_frames
      assert_equal edit_line("@name").linkable_id, focused_drawable.linkable_id
      assert_equal text, edit_line("@name").text
      assert_includes text, "Updated"
    TEST
    assert_spec_passed(run)
  end
end
