# frozen_string_literal: true

module Scarpe::Native
  # The event loop (DESIGN 5.4). The run handler answers custom_event_loop "return", so
  # Shoes.app returns and this loop runs from at_exit, the only arrangement that allows window().
  #
  #   until no apps remain or the child exited:
  #     wait for input, at most until the next timer deadline (or a second, idle)
  #     dispatch every complete message; fire due timers; heartbeat (throttled); flush
  #
  # An idle app sleeps: Rust's messages, a post from another thread and Ctrl-C all wake the wait
  # (Child#wake!), so the idle wait only bounds how late anything else could be noticed.
  class Pump
    LONGEST_WAIT = 0.05
    IDLE_WAIT = 1.0
    HEARTBEAT_EVERY = 0.05

    def initialize(service)
      @service = service
      @last_heartbeat_at = nil
    end

    def install
      return if @installed

      @installed = true
      Stats.mark("run")
      wake_on_interrupt
      # A script that died with an exception (or called exit) wants to stop, not show a window.
      at_exit { run unless $! }
    end

    def run
      Stats.mark("pump")
      step(IDLE_WAIT) until done?
      raise ChildDied, @service.child.death_report if @service.child.dead? && @service.any_app_open?
    ensure
      @service.shutdown
      Stats.write
    end

    def done?
      !@service.any_app_open? || @service.child.dead?
    end

    # One turn of the loop. `longest`: how long to wait for input; callers that step toward a
    # deadline of their own (Automation#advance) keep the default.
    def step(longest = LONGEST_WAIT)
      @service.child.check_started!
      Stats.time(:wait) { @service.child.wait_for_input(wait_time(longest)) }
      Stats.time(:drain) { drain }
      Stats.time(:timers) { @service.fire_timers }
      Stats.time(:heartbeat) { heartbeat }
      Stats.time(:flush) { @service.child.flush }
    end

    # Dispatches everything already read. Handlers can make requests that queue more; keep going.
    def drain
      until (messages = @service.child.messages).empty?
        messages.each { |message| @service.receive(message) }
      end
    end

    private

    def wait_time(longest)
      due = @service.timers.next_due_at
      return longest unless due

      (due - @service.clock.now).clamp(0, longest)
    end

    # Lacci quits on Ctrl-C from a signal trap, which may only flip flags (DisplayService#quit_all);
    # a sleeping pump would not look at them until it woke. The trap now wakes it too.
    def wake_on_interrupt
      child = @service.child
      previous = Signal.trap("INT") do |signal|
        previous.arity.zero? ? previous.call : previous.call(signal)
        child.wake!
      end
      Signal.trap("INT", previous) unless previous.respond_to?(:call)
    end

    def heartbeat
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return if @last_heartbeat_at && now - @last_heartbeat_at < HEARTBEAT_EVERY

      @last_heartbeat_at = now
      @service.dispatch_heartbeat
    end
  end
end
