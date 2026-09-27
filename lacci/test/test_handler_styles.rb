# frozen_string_literal: true

require_relative "test_helper"

# Ledger G10: "The click event handler is stored in this style" (manual 1144-1151) and
# likewise change (manual 1123-1128). A proc given as the style is the handler, and a
# handler given as a block reads back through style.
class TestHandlerStyles < NienteTest
  def test_click_and_change_procs_are_the_handlers
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $heard = []
        button "Go", click: proc { |b| $heard << [:button, b.text] }
        check click: proc { $heard << :check }
        edit_line change: proc { |e| $heard << [:line, e.text] }
        edit_box change: proc { $heard << :box }
        list_box items: %w[a b], change: proc { |l| $heard << [:list, l.text] }
        para "Tap", click: proc { |button, left, top| $heard << [:para, button, left, top] }
        $box = stack(click: proc { |button| $heard << [:stack, button] }) { para "inside" }
      end
    SHOES_APP
      fire = ->(event, drawable, *args) { Shoes::DisplayService.dispatch_event(event, drawable.linkable_id, *args) }
      fire.("click", button)
      fire.("click", check)
      fire.("change", edit_line, "hi")
      fire.("change", edit_box, "there")
      fire.("change", list_box, "b")
      fire.("click", paras.find { |p| p.text == "Tap" }, 1, 5, 6)
      fire.("click", $box.contents.find { |d| d.is_a?(Shoes::SubscriptionItem) }, 2, 0, 0)

      assert_equal [[:button, "Go"], :check, [:line, "hi"], :box, [:list, "b"], [:para, 1, 5, 6], [:stack, 2]], $heard
    SHOES_SPEC
  end

  def test_handlers_read_back_through_style
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @go = button("Go") { }
        @line = edit_line
        @line.change { }
        @shape = rect 0, 0, 10
        @shape.click { }
      end
    SHOES_APP
      assert_kind_of Proc, button.style[:click]
      assert_kind_of Proc, edit_line.style[:change]
      assert_kind_of Proc, rect.style[:click]
    SHOES_SPEC
  end
end
