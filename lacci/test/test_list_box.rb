# frozen_string_literal: true

require_relative "test_helper"

# DESIGN.md section 10, item 4. Manual: the list_box block is its change
# block (manual.md:3186-3206) and choose(item) returns self (manual.md:3213).
class TestListBox < NienteTest
  def test_creation_block_is_the_change_handler
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @picked = []
        list_box(items: %w[a b c]) { |box| @picked << box.text }
      end
    SHOES_APP
      Shoes::DisplayService.dispatch_event("change", list_box.linkable_id, "b")
      assert_equal ["b"], Shoes.APPS[0].instance_variable_get(:@picked)
    SHOES_SPEC
  end

  def test_choose_tells_the_display
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        list_box(items: %w[a b c])
      end
    SHOES_APP
      box = list_box
      assert_same box.obj, box.choose("c")
      assert_equal "c", box.text
      assert_equal "c", box.display.instance_variable_get(:@chosen)
    SHOES_SPEC
  end
end
