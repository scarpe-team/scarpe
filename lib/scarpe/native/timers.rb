# frozen_string_literal: true

module Scarpe::Native
  # Monotonic time that tests can stop. Once frozen, it only moves when told to, so
  # Shoes-Spec's advance(seconds) fires exactly the timers due in that span.
  class Clock
    def now
      @frozen_at || monotonic
    end

    def freeze!
      @frozen_at ||= monotonic
    end

    def frozen?
      !@frozen_at.nil?
    end

    def travel_to(time)
      @frozen_at = time if frozen? && time > @frozen_at
    end

    private

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  # animate, every and timer, ticked by the Ruby pump (DESIGN 5.4). Rust has no timer logic.
  # animate(fps = 10) sends frame 0, 1, 2...; every(secs) sends count 0, 1, 2... (Shoes 3 and 4, ledger I1);
  # timer(secs = 1) fires once.
  #
  # Deadlines are origin + slot * interval rather than a running sum, so ten 0.1 s frames land
  # on exactly one second instead of drifting past it.
  class Timers
    Timer = Struct.new(:id, :app_id, :event, :interval, :origin, :slot, :counter, :stopped, keyword_init: true) do
      def due_at
        origin + slot * interval
      end
    end

    DEFAULT_FPS = 10.0
    DEFAULT_SECONDS = 1.0
    SHORTEST_INTERVAL = 0.001
    EPSILON = 1e-9

    def initialize
      @timers = {}
    end

    def add(id, api_name, args, now:, app_id: nil, stopped: false)
      interval, counter = schedule_for(api_name, Array(args).first)
      return unless interval

      @timers[id] = Timer.new(id: id, app_id: app_id, event: api_name, interval: interval,
        origin: now, slot: 1, counter: counter, stopped: !!stopped)
    end

    def remove(id)
      @timers.delete(id)
    end

    def remove_app(app_id)
      @timers.delete_if { |_id, timer| timer.app_id == app_id }
    end

    def include?(id)
      @timers.key?(id)
    end

    def [](id)
      @timers[id]
    end

    # A restarted timer waits a whole interval rather than firing at once for the time it was stopped.
    def set_stopped(id, stopped, now:)
      timer = @timers[id] or return
      if timer.stopped && !stopped
        timer.origin = now
        timer.slot = 1
      end
      timer.stopped = !!stopped
    end

    def next_due_at
      running.map(&:due_at).min
    end

    # Yields (event, id, args) for every timer due by now, earliest first. Handlers may add or
    # remove timers while this runs. A timer that fell behind (a slow handler, a blocked loop)
    # skips the deadlines it missed instead of firing a burst to catch up.
    def fire_due(now)
      while (timer = running.select { |t| t.due_at <= now + EPSILON }.min_by(&:due_at))
        yield timer.event, timer.id, fire(timer, now)
      end
    end

    # Whether a timer set to run on the next turn of the loop (timer(0) and anything under a
    # millisecond) is due by now.
    def next_turn_due?(now)
      running.any? { |t| t.interval <= SHORTEST_INTERVAL && t.due_at <= now + EPSILON }
    end

    private

    def running
      @timers.values.reject(&:stopped)
    end

    def fire(timer, now)
      return @timers.delete(timer.id) && [] if timer.event == "timer"

      args = [timer.counter]
      timer.counter += 1
      timer.slot += 1
      timer.slot = ((now - timer.origin) / timer.interval).floor + 1 if timer.due_at <= now + EPSILON
      args
    end

    def schedule_for(api_name, arg)
      case api_name
      when "animate" then [1.0 / positive(arg, DEFAULT_FPS), 0]
      when "every" then [seconds(arg), 0]
      when "timer" then [seconds(arg), nil]
      end
    end

    def positive(value, default)
      number = value.respond_to?(:to_f) ? value.to_f : 0.0
      number.positive? ? number : default
    end

    # No number waits the default second. Anything shorter than a millisecond, zero and
    # below included, is a millisecond, as in Shoes 3 (s3t_timerbase.c:72): timer(0) fires
    # on the next turn of the loop.
    def seconds(value)
      return DEFAULT_SECONDS if value.nil? || !value.respond_to?(:to_f)

      [value.to_f, SHORTEST_INTERVAL].max
    end
  end
end
