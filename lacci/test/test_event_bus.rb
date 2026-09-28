# frozen_string_literal: true

require_relative "test_helper"

# Unsubscribing used to scan every subscription in the process and leave emptied
# lists behind, so destroying N drawables cost N x (everything). Clearing a
# 2000-para stack took seconds. Subscriptions are indexed by their unsub id now.
class TestEventBus < Minitest::Test
  def setup
    return if Shoes::Log.instance

    require "scarpe/components/print_logger"
    Shoes::Log.instance = Scarpe::Components::PrintLogImpl.new
    printer = Scarpe::Components::PrintLogImpl::PrintLogger
    printer.min_level = printer::LEVELS[:warn]
  end

  def handlers
    Shoes::DisplayService.class_variable_get(:@@display_event_handlers)
  end

  def test_unsubscribing_the_last_handler_forgets_the_target_and_the_name
    id = Shoes::DisplayService.subscribe_to_event("bus_test_ping", 4242) { }
    Shoes::DisplayService.unsub_from_events(id)

    refute handlers.key?("bus_test_ping"), "an event name with no handlers left is dropped"
  end

  def test_unsubscribing_one_handler_keeps_its_neighbours
    heard = []
    first = Shoes::DisplayService.subscribe_to_event("bus_test_pong", 7) { heard << :first }
    Shoes::DisplayService.subscribe_to_event("bus_test_pong", 7) { heard << :second }
    Shoes::DisplayService.subscribe_to_event("bus_test_pong", 8) { heard << :other }

    Shoes::DisplayService.unsub_from_events(first)
    Shoes::DisplayService.dispatch_event("bus_test_pong", 7)
    Shoes::DisplayService.dispatch_event("bus_test_pong", 8)

    assert_equal [:second, :other], heard
  end

  def test_unsubscribing_twice_is_harmless
    id = Shoes::DisplayService.subscribe_to_event("bus_test_twice", nil) { }
    Shoes::DisplayService.unsub_from_events(id)
    Shoes::DisplayService.unsub_from_events(id)

    refute handlers.key?("bus_test_twice")
  end

  def test_a_handler_may_unsubscribe_itself_while_the_event_is_dispatched
    calls = 0
    id = Shoes::DisplayService.subscribe_to_event("bus_test_once", nil) do
      calls += 1
      Shoes::DisplayService.unsub_from_events(id)
    end

    2.times { Shoes::DisplayService.dispatch_event("bus_test_once", nil) }

    assert_equal 1, calls
  end
end

class TestEventBusAfterClear < NienteTest
  def test_clearing_a_slot_leaves_no_subscriptions_for_its_children
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @box = stack { 20.times { |i| para "line \#{i}" } }
      end
    SHOES_APP
      box = stack("@box")
      ids = box.contents.map(&:linkable_id)
      box.clear

      handlers = Shoes::DisplayService.class_variable_get(:@@display_event_handlers)
      leftovers = handlers.flat_map { |name, targets| (targets.keys & ids).map { |id| [name, id] } }
      assert_empty leftovers, "destroyed paras keep nothing on the bus, in Lacci or in Niente"
    SHOES_SPEC
  end

  # A drawable subscribes to its hover, leave and motion only once given a block for them.
  # Hackety Hack's editor makes about a thousand spans on every key, and each left three
  # subscriptions behind.
  def test_drawables_subscribe_to_pointer_events_only_when_given_a_block
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        handlers = Shoes::DisplayService.class_variable_get(:@@display_event_handlers)
        pointer = -> { %w[hover leave motion].sum { |name| (handlers[name] || {}).values.sum(&:size) } }
        before = pointer.call
        200.times { span("token") }
        $grew = pointer.call - before
        @word = para "hover me"
        @word.hover { $hovered = true }
      end
    SHOES_APP
      assert_equal 0, $grew, "two hundred spans subscribe to no pointer events"
      Shoes::DisplayService.dispatch_event("hover", para("@word").linkable_id)
      assert $hovered, "and a hover block given later is heard"
    SHOES_SPEC
  end
end
