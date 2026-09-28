# frozen_string_literal: true

require_relative "helper"

class TimersTest < Minitest::Test
  Timers = Scarpe::Native::Timers

  def setup
    @timers = Timers.new
    @fired = []
  end

  def fire_until(time)
    @timers.fire_due(time) { |event, id, args| @fired << [event, id, args] }
  end

  # Steps through deadlines the way Shoes-Spec's advance does.
  def advance_to(time)
    while (due = @timers.next_due_at) && due <= time + Timers::EPSILON
      fire_until(due)
    end
  end

  def test_animate_counts_frames_from_zero_at_its_fps
    @timers.add(1, "animate", [10], now: 100.0)
    advance_to(101.0)
    assert_equal (0..9).map { |frame| ["animate", 1, [frame]] }, @fired
  end

  def test_animate_defaults_to_ten_fps
    @timers.add(1, "animate", [], now: 0.0)
    assert_in_delta 0.1, @timers.next_due_at
  end

  def test_every_counts_from_zero
    @timers.add(2, "every", [0.5], now: 0.0)
    advance_to(2.0)
    assert_equal [[0], [1], [2], [3]], @fired.map(&:last)
  end

  def test_timer_fires_once
    @timers.add(3, "timer", [0.25], now: 0.0)
    advance_to(0.2)
    assert_empty @fired
    advance_to(5.0)
    assert_equal [["timer", 3, []]], @fired
    refute @timers.include?(3)
  end

  def test_timer_defaults_to_one_second
    @timers.add(3, "timer", nil, now: 0.0)
    assert_in_delta 1.0, @timers.next_due_at
  end

  # Shoes 3 turns a rate under a millisecond into one millisecond (s3t_timerbase.c:72), so
  # timer(0) fires on the next turn of the loop; it waited the default second here, and a run
  # of `timer(i * 0.12)` fired its first last (examples/native/kids/_repros/bubble_garden_1.rb).
  def test_a_zero_or_negative_timer_fires_on_the_next_turn
    [0, 0.0, -1].each_with_index { |delay, id| @timers.add(id, "timer", [delay], now: 0.0) }
    @timers.add(3, "timer", [0.12], now: 0.0)
    advance_to(0.2)
    assert_equal [0, 1, 2, 3], @fired.map { |fired| fired[1] }, "the zero timers come first, in order"
  end

  def test_every_zero_repeats_at_the_shortest_interval
    @timers.add(1, "every", [0], now: 0.0)
    assert_in_delta Timers::SHORTEST_INTERVAL, @timers.next_due_at
  end

  def test_timers_fire_in_deadline_order
    @timers.add(1, "every", [0.3], now: 0.0)
    @timers.add(2, "timer", [0.1], now: 0.0)
    advance_to(0.3)
    assert_equal ["timer", "every"], @fired.map(&:first)
  end

  def test_stopped_timers_do_not_fire_and_restart_a_full_interval_later
    @timers.add(1, "every", [1], now: 0.0, stopped: true)
    assert_nil @timers.next_due_at
    fire_until(10.0)
    assert_empty @fired

    @timers.set_stopped(1, false, now: 10.0)
    fire_until(10.5)
    assert_empty @fired
    fire_until(11.0)
    assert_equal [["every", 1, [0]]], @fired
  end

  def test_stop_mid_run_keeps_the_count
    @timers.add(1, "animate", [10], now: 0.0)
    advance_to(0.2)
    @timers.set_stopped(1, true, now: 0.2)
    advance_to(5.0)
    @timers.set_stopped(1, false, now: 5.0)
    advance_to(5.1)
    assert_equal([0, 1, 2], @fired.map { |f| f.last.first })
  end

  def test_a_timer_that_fell_behind_skips_instead_of_bursting
    @timers.add(1, "animate", [10], now: 0.0)
    fire_until(1.05)
    assert_equal [[0]], @fired.map(&:last), "one frame, not ten"
    assert_in_delta 1.1, @timers.next_due_at
  end

  def test_removed_timers_are_forgotten
    @timers.add(1, "every", [1], now: 0.0)
    @timers.remove(1)
    fire_until(10.0)
    assert_empty @fired
  end

  def test_remove_app_drops_only_that_apps_timers
    @timers.add(1, "every", [1], now: 0.0, app_id: 10)
    @timers.add(2, "every", [1], now: 0.0, app_id: 20)
    @timers.remove_app(10)
    refute @timers.include?(1)
    assert @timers.include?(2)
  end

  def test_handlers_may_add_timers_while_firing
    @timers.add(1, "timer", [1], now: 0.0)
    @timers.fire_due(1.0) do |_event, id, _args|
      @fired << id
      @timers.add(2, "timer", [1], now: 1.0) if id == 1
    end
    assert_equal [1], @fired
    assert @timers.include?(2)
  end

  def test_non_timer_subscriptions_are_ignored
    assert_nil @timers.add(1, "click", [], now: 0.0)
    refute @timers.include?(1)
  end

  def test_clock_only_moves_when_told_once_frozen
    clock = Scarpe::Native::Clock.new
    refute clock.frozen?
    start = clock.freeze!
    assert_equal start, clock.now
    clock.travel_to(start + 2)
    assert_equal start + 2, clock.now
    clock.travel_to(start + 1)
    assert_equal start + 2, clock.now, "never backwards"
  end
end
