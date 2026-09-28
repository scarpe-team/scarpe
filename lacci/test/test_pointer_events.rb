# frozen_string_literal: true

require_relative "test_helper"

# Manual: click { |button, left, top| } and release work on shapes and text
# blocks too (manual.md:1144-1151, 2187-2193, 2277-2284). DESIGN.md section 10, item 9.
class TestPointerEvents < NienteTest
  def test_rect_click_and_release_get_button_and_position
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @presses = []
        rect(10, 10, 50, 50)
          .click { |button, left, top| @presses << [:click, button, left, top] }
          .release { |button, left, top| @presses << [:release, button, left, top] }
      end
    SHOES_APP
      rect.trigger_click(1, 20, 30)
      Shoes::DisplayService.dispatch_event("release", rect.linkable_id, 1, 21, 31)
      assert_equal [[:click, 1, 20, 30], [:release, 1, 21, 31]],
        Shoes.APPS[0].instance_variable_get(:@presses)
    SHOES_SPEC
  end

  def test_display_is_told_once_which_drawables_take_presses
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $pointer_flags = []
        Shoes::DisplayService.subscribe_to_event("prop_change", :any) do |changes, **_kwargs|
          $pointer_flags << changes if changes.key?("has_click") || changes.key?("has_release")
        end

        @clicks = []
        @p = para "Click me"
        @p.click { @clicks << :first }
        @p.click { @clicks << :second }
        @p.release { }
      end
    SHOES_APP
      assert_equal [{ "has_click" => true }, { "has_release" => true }], $pointer_flags
      assert_equal true, para.display.instance_variable_get(:@has_click)

      para.trigger_click(1, 0, 0)
      assert_equal [:second], Shoes.APPS[0].instance_variable_get(:@clicks)
    SHOES_SPEC
  end

  # Widgets keep their own no-argument click and never ask for pointer routing.
  def test_button_click_is_unchanged
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @pushed = 0
        button("Push") { @pushed += 1 }
      end
    SHOES_APP
      button.trigger_click
      assert_equal 1, Shoes.APPS[0].instance_variable_get(:@pushed)
      assert_nil button.display.instance_variable_get(:@has_click)
    SHOES_SPEC
  end

  # An edit_line's change handler used to live in the same slot click wrote to.
  def test_click_does_not_replace_an_edit_line_change_handler
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @typed = []
        edit_line { |line| @typed << line.text }.click { }
      end
    SHOES_APP
      Shoes::DisplayService.dispatch_event("change", edit_line.linkable_id, "hi")
      assert_equal ["hi"], Shoes.APPS[0].instance_variable_get(:@typed)
    SHOES_SPEC
  end
end
