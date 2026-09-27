# frozen_string_literal: true

module Scarpe::Native
  # The event loop (DESIGN 5.4). The run handler answers custom_event_loop "return", so
  # Shoes.app returns and this loop runs from at_exit, the only arrangement that allows window().
  #
  #   until no apps remain or the child exited:
  #     wait for input, at most until the next timer deadline or 50 ms
  #     dispatch every complete message; fire due timers; heartbeat (throttled); flush
  class Pump
    LONGEST_WAIT = 0.05
    HEARTBEAT_EVERY = 0.05

    def initialize(service)
      @service = service
      @last_heartbeat_at = nil
    end

    def install
      return if @installed

      @installed = true
      # A script that died with an exception (or called exit) wants to stop, not show a window.
      at_exit { run unless $! }
    end

    def run
      step until done?
      raise ChildDied, @service.child.death_report if @service.child.dead? && @service.any_app_open?
    ensure
      @service.shutdown
    end

    def done?
      !@service.any_app_open? || @service.child.dead?
    end

    def step
      @service.child.wait_for_input(wait_time)
      drain
      @service.fire_timers
      heartbeat
      @service.child.flush
    end

    # Dispatches everything already read. Handlers can make requests that queue more; keep going.
    def drain
      until (messages = @service.child.messages).empty?
        messages.each { |message| @service.receive(message) }
      end
    end

    private

    def wait_time
      due = @service.timers.next_due_at
      return LONGEST_WAIT unless due

      (due - @service.clock.now).clamp(0, LONGEST_WAIT)
    end

    def heartbeat
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return if @last_heartbeat_at && now - @last_heartbeat_at < HEARTBEAT_EVERY

      @last_heartbeat_at = now
      @service.dispatch_heartbeat
    end
  end
end
