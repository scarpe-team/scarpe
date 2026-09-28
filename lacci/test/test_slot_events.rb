# frozen_string_literal: true

require_relative "test_helper"

class TestSlotEvents < NienteTest
  # Ledger H5: hover and leave hand the block "the object which was hovered over"
  # (manual 2200-2205, 2251-2257), the slot rather than its SubscriptionItem.
  def test_hover_and_leave_hand_over_what_was_hovered
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $handed = []
        $box = stack do
          hover { |s| $handed << [:hover, s] }
          leave { |s| $handed << [:leave, s] }
        end
        $words = para("words").hover { |p| $handed << [:para, p] }
      end
    SHOES_APP
      watchers = $box.contents.select { |d| d.is_a?(Shoes::SubscriptionItem) }
      watchers.each { |w| Shoes::DisplayService.dispatch_event(w.shoes_api_name, w.linkable_id) }
      Shoes::DisplayService.dispatch_event("hover", $words.linkable_id)

      assert_equal [[:hover, $box], [:leave, $box], [:para, $words]], $handed
    SHOES_SPEC
  end

  # The manual's own example (2167-2185): hovering clears the slot, and the leave
  # handler must survive that to turn it red again. Shoes 3's clear empties the
  # slot's contents only (s3_canvas.c:759-781); handlers and timers stay.
  def test_clear_keeps_the_slots_handlers_and_timers
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $ticks = 0
        $s = stack width: 200, height: 200 do
          background red
          hover { $s.clear { background blue } }
          leave { $s.clear { background red } }
          every(1) { $ticks += 1 }
        end
      end
    SHOES_APP
      watcher = ->(name) { $s.contents.find { |d| d.is_a?(Shoes::SubscriptionItem) && d.shoes_api_name == name } }
      colour = -> { $s.contents.find { |d| d.is_a?(Shoes::Background) }.fill }

      Shoes::DisplayService.dispatch_event("hover", watcher.("hover").linkable_id)
      assert_equal [0, 0, 255, 255], colour.()
      Shoes::DisplayService.dispatch_event("leave", watcher.("leave").linkable_id)
      assert_equal [255, 0, 0, 255], colour.(), "the leave handler outlived the hover's clear"

      Shoes::DisplayService.dispatch_event("every", watcher.("every").linkable_id, 0)
      assert_equal 1, $ticks, "and so did the timer"
    SHOES_SPEC
  end

  # Ledger H6: a slot keeps one handler per event, as Shoes 3 does (EVENT_HANDLER stores
  # one proc per slot per event, s3_canvas.c:934-955), so registering it again replaces the
  # first. Hackety Hack's editor rebuilds its slot with clear and gives it a keypress each
  # time; with both kept, every key was typed twice, then three times.
  def test_registering_a_slot_event_again_replaces_the_first
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $seen = []
        $editor = stack do
          keypress { |k| $seen << [:first, k] }
          click { $seen << [:click] }
        end
        $editor.clear do
          keypress { |k| $seen << [:second, k] }
        end
      end
    SHOES_APP
      handlers = ->(name) { $editor.contents.select { |d| d.is_a?(Shoes::SubscriptionItem) && d.shoes_api_name == name } }
      assert_equal 1, handlers.("keypress").size, "one keypress handler is left"
      Shoes::DisplayService.dispatch_event("keypress", handlers.("keypress").first.linkable_id, "a")
      assert_equal [[:second, "a"]], $seen

      assert_equal 1, handlers.("click").size, "another event's handler is not touched"
      $editor.click { $seen << [:click_again] }
      assert_equal 1, handlers.("click").size
      Shoes::DisplayService.dispatch_event("click", handlers.("click").first.linkable_id, 1, 0, 0)
      assert_equal [:click_again], $seen.last
    SHOES_SPEC
  end

  # Visiting a page starts from nothing, handlers and timers included, as Shoes 3
  # resets the whole canvas on visit.
  def test_visiting_a_page_drops_the_old_pages_handlers
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        keypress { }
        page(:two) { para "two" }
      end
    SHOES_APP
      handler = subscription_item.obj
      Shoes.APPS.first.visit(:two)
      assert handler.destroyed
    SHOES_SPEC
  end

  # Ledger H8: start { |slot| } runs the first time the slot is drawn, which the
  # display marks with its first heartbeat; finish { |slot| } runs when the slot goes.
  # Both are handed the slot, and both work inside the slot's own block.
  def test_start_and_finish_are_handed_the_slot
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $events = []
        @holder = stack do
          $inner = stack do
            para "here"
            start { |slot| $events << [:start, slot] }
            finish { |slot| $events << [:finish, slot] }
          end
        end
        $holder = @holder
      end
    SHOES_APP
      2.times { Shoes::DisplayService.dispatch_event("heartbeat", nil) }
      assert_equal [[:start, $inner]], $events, "start ran once"

      $holder.clear
      assert_equal [[:start, $inner], [:finish, $inner]], $events
    SHOES_SPEC
  end

  # Ledger B5: remove used to skip the slot's own destroy, so finish never ran.
  def test_removing_a_slot_fires_finish
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $finished = []
        $slot = stack { para "going away" }
        $slot.finish { |slot| $finished << slot }
      end
    SHOES_APP
      child = $slot.contents.first
      assert_same $slot, $slot.remove
      assert_equal [$slot], $finished
      assert child.destroyed, "and its children went with it"
    SHOES_SPEC
  end
end
