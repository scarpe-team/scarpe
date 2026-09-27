# frozen_string_literal: true

require_relative "test_helper"

# Methods the manual heads with "» self" return self, so calls chain and
# `@r = rect(...).hide` keeps the rect (expert/colours.rb, expert/tooltips.rb do
# exactly that). They used to return whatever their last line produced.
class TestReturnsSelf < NienteTest
  def test_hide_show_and_toggle
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $r = rect(0, 0, 10).hide
      end
    SHOES_APP
      assert_kind_of Shoes::Rect, $r
      assert_same $r, $r.show
      assert_same $r, $r.toggle
      assert $r.hidden
    SHOES_SPEC
  end

  def test_slot_manipulation
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $slot = stack { para "first" }
        @go = button("Go") do
          $returned = [
            $slot.append { para "last" },
            $slot.prepend { para "zeroth" },
            $slot.clear { para "again" },
            $slot.clear,
          ]
          $app_returned = [append { para "x" }, clear]
        end
      end
    SHOES_APP
      button("@go").trigger_click
      assert_equal [$slot] * 4, $returned
      assert_equal [Shoes.APPS.first] * 2, $app_returned
    SHOES_SPEC
  end

  def test_slot_events_return_the_slot_and_timers_return_the_timer
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $slot = stack { para "listening" }
        $app_click = click { }
        $anim = animate(10) { }
      end
    SHOES_APP
      %i[click release hover leave motion keypress wheel start finish].each do |event|
        assert_same $slot, $slot.public_send(event) { }, "\#{event} { } returns the slot"
      end
      assert_same Shoes.APPS.first, $app_click
      assert_kind_of Shoes::SubscriptionItem, $anim
      assert_same $anim, $anim.stop
      assert_same $anim, $anim.start
      assert_same $anim, $anim.toggle
    SHOES_SPEC
  end
end
