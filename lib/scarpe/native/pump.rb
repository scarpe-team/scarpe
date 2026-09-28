# frozen_string_literal: true

module Scarpe::Native
  # The event loop (DESIGN 5.4). The run handler answers custom_event_loop "return", so
  # Shoes.app returns and this loop runs from at_exit, the only arrangement that allows window().
  #
  #   until no apps remain or the child exited:
  #     wait for input, at most until the next timer deadline (or a second, idle)
  #     dispatch every complete message; what programs Shoes.run_program started said;
  #     fire due timers; heartbeat (throttled); flush
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
      @interrupts = 0
    end

    # Called at every run: each Shoes::App traps INT afresh as it is made (a window, a dialog),
    # which drops the pump's link in the chain, so it goes back on for the app about to run.
    def install
      wake_on_interrupt
      return if @installed

      @installed = true
      Stats.mark("run")
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
      Stats.time(:programs) { @service.dispatch_programs }
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

    # Lacci quits on Ctrl-C from a signal trap, which may only flip flags (DisplayService#quit_all);
    # a sleeping pump would not look at them until it woke. The trap now wakes it too. A second
    # Ctrl-C ends the child as well: Ruby may be stuck writing to a child that stopped reading,
    # where asking it to quit changes nothing.
    def wake_on_interrupt
      child = @service.child
      previous = nil
      chained = proc do |signal|
        previous.arity.zero? ? previous.call : previous.call(signal)
        (@interrupts += 1) > 1 ? child.kill! : child.wake!
      end
      previous = Signal.trap("INT", chained)
      return @chained = chained if previous.respond_to?(:call) && !previous.equal?(@chained)

      Signal.trap("INT", previous) # nothing new to chain: ours is still on, or no app trapped INT
    end

    private

    def wait_time(longest)
      return 0 if @service.programs.waiting?

      due = @service.timers.next_due_at
      return longest unless due

      (due - @service.clock.now).clamp(0, longest)
    end

    def heartbeat
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return if @last_heartbeat_at && now - @last_heartbeat_at < HEARTBEAT_EVERY

      @last_heartbeat_at = now
      @service.dispatch_heartbeat
    end
  end
end
