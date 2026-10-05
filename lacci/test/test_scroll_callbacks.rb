# frozen_string_literal: true

require_relative "test_helper"

class TestScrollCallbacks < NienteTest
  def test_notifications_update_the_offset_first_and_keep_the_blocks_self
    run_test_niente_code(<<~APP, app_test_code: <<~TEST)
      Shoes.app { $list = stack(height: 100, scroll: true) }
    APP
      seen = []
      assert_same $list, $list.on_scroll { |top| seen << [self, top, $list.scroll_top] }
      $list.scrolled_to(0)
      assert_empty seen, "an unset offset is already zero"
      $list.scrolled_to(40)
      $list.scrolled_to(40)
      $list.scrolled_to(0)
      assert_equal [[self, 40, 40], [self, 0, 0]], seen
    TEST
  end

  def test_a_handler_survives_clear_can_be_replaced_and_can_be_removed
    run_test_niente_code(<<~APP, app_test_code: <<~TEST)
      Shoes.app { $list = stack { para "old" } }
    APP
      seen = []
      $list.on_scroll { |top| seen << [:first, top] }
      $list.scrolled_to(10)
      $list.clear { $list.para "new" }
      $list.scrolled_to(20)
      assert_same $list, $list.on_scroll { |top| seen << [:second, top] }
      $list.scrolled_to(30)
      assert_same $list, $list.on_scroll
      $list.scrolled_to(40)
      assert_equal [[:first, 10], [:first, 20], [:second, 30]], seen
      assert_equal 40, $list.scroll_top, "removing the callback does not stop state updates"
    TEST
  end

  def test_ruby_positioning_is_silent_for_stacks_flows_and_the_window_root
    run_test_niente_code(<<~APP, app_test_code: <<~TEST)
      Shoes.app do
        $stack = stack
        $flow = flow
      end
    APP
      [$stack, $flow, Shoes.APPS.first.document_root].each do |slot|
        seen = []
        slot.on_scroll { |top| seen << top }
        slot.scroll_top = 25
        assert_equal 25, slot.scroll_top
        slot.scrolled_to(25)
        assert_empty seen, "assignments and identical reports do not notify"
        slot.scrolled_to(30)
        assert_equal [30], seen
      end
    TEST
  end

  def test_removing_a_parent_stops_notifications_for_its_nested_slots
    run_test_niente_code(<<~APP, app_test_code: <<~TEST)
      Shoes.app do
        $parent = stack { $list = stack }
      end
    APP
      seen = []
      $list.on_scroll { |top| seen << top }
      $list.scrolled_to(10)
      $parent.clear
      assert $list.destroyed
      $list.scrolled_to(20)
      assert_equal [10], seen
      assert_equal 10, $list.scroll_top, "late reports cannot mutate a destroyed slot"
    TEST
  end
end
