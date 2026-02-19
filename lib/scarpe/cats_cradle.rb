# frozen_string_literal: true

require "scarpe/components/unit_test_helpers"

require "fiber"

module Scarpe
  # This class defines the CatsCradle DSL. It also holds a "bag of fibers"
  # with promises for when they should next resume.
  class CCInstance
    include Shoes::Log
    include Scarpe::Test::Helpers

    def self.instance
      @instance ||= CCInstance.new
    end

    def initialize
      log_init("CatsCradle")

      @waiting_fibers = []
      @event_promises = {}
      @timed_promises = []  # Array of { deadline:, promise: } for time-based waits
      @shutdown = false

      @manager_fiber = Fiber.new do
        Fiber[:catscradle] = true

        loop do
          # A fiber can run briefly and then exit. It can run and then block on an API call.
          # These fibers return promises to indicate to CatsCradle when they can run again.
          # A fiber that is no longer #alive? is assumed to be successfully finished.
          @waiting_fibers.each do |fiber_data|
            next if !fiber_data[:promise].fulfilled? || !fiber_data[:fiber].alive? || @shutdown

            @log.debug("Resuming fiber with value #{fiber_data[:promise].returned_value.inspect}")
            result = fiber_data[:fiber].transfer fiber_data[:promise].returned_value

            # Dead fibers will be removed later, just leave it
            next unless fiber_data[:fiber].alive?

            case result
            when ::Scarpe::Promise
              fiber_data[:promise] = result
            else
              raise Scarpe::UnexpectedFiberTransferError, "Unexpected object returned from Fiber#transfer for still-living Fiber! #{result.inspect}"
            end
          end

          # Throw out dead fibers or those that will never wake
          @waiting_fibers.select! do |fiber_data|
            fiber_data[:fiber].alive? && !fiber_data[:promise].rejected?
          end

          # Done with this iteration
          Fiber.yield
        end
      end
    end

    private

    def cc_fiber(&block)
      Fiber.new do
        Fiber[:catscradle] = true
        CCInstance.instance.instance_eval(&block)
      end
    end

    public

    # If we add "every" events, that's likely to complicate timing and event_promise handling.
    EVENT_TYPES = [:init, :next_heartbeat, :next_redraw, :every_heartbeat, :every_redraw]

    # This needs to be called after the basic display service objects exist
    # and we can find the control interface.
    def event_init
      return if @cc_init_done

      @cc_init_done = true

      @control_interface = ::Shoes::DisplayService.display_service.control_interface
      @wrangler = @control_interface.wrangler

      cc_instance = self # ControlInterface#on_event does an instance eval. We'll reset self with another.

      @control_interface.on_event(:every_heartbeat) do
        cc_instance.instance_eval do
          p = @event_promises.delete(:next_heartbeat)
          p&.fulfilled!

          p = @event_promises.delete(:every_heartbeat)
          p&.fulfilled!

          # Check and fulfill any timed promises that have reached their deadline
          now = Time.now
          @timed_promises.each do |tp|
            if now >= tp[:deadline] && !tp[:promise].fulfilled?
              tp[:promise].fulfilled!
            end
          end
          @timed_promises.reject! { |tp| tp[:promise].fulfilled? }

          # Reschedule on_every_heartbeat fibers for next heartbeat, too.
          # This fiber won't be called again by a heartbeat, though it may
          # continue if it waits on another promise.
          @waiting_fibers.select { |f| f[:on_event] == :every_heartbeat }.each do |f|
            on_event(:every_heartbeat, &f[:block])
          end

          # Give every ready fiber a chance to run once.
          @manager_fiber.resume unless @shutdown
        end unless @shutdown
      end

      @control_interface.on_event(:every_redraw) do
        cc_instance.instance_eval do
          p = @event_promises.delete(:next_redraw)
          p&.fulfilled!

          p = @event_promises.delete(:every_redraw)
          p&.fulfilled!

          # Reschedule on_every_redraw fibers for next redraw, too.
          @waiting_fibers.select { |f| f[:on_event] == :every_redraw }.each do |f|
            on_event(:every_redraw, &f[:block])
          end

          # Give every ready fiber a chance to run once.
          @manager_fiber.resume unless @shutdown
        end unless @shutdown
      end
    end

    def fiber_start
      @manager_fiber.resume unless @shutdown
    end

    def event_promise(event)
      @event_promises[event] ||= ::Scarpe::Promise.new
    end

    def on_event(event, &block)
      raise Scarpe::UnknownEventTypeError, "Unknown event type: #{event.inspect}!" unless EVENT_TYPES.include?(event)
      return if @shutdown

      @waiting_fibers << { promise: event_promise(event), fiber: cc_fiber(&block), on_event: event, block: }
    end

    def active_fiber(&block)
      return if @shutdown

      p = ::Scarpe::Promise.new
      p.fulfilled!
      @waiting_fibers << { promise: p, fiber: cc_fiber(&block), on_event: nil, block: }
    end

    def wait(promise)
      raise(Scarpe::InvalidPromiseError, "Must supply a promise to wait!") unless promise.is_a?(::Scarpe::Promise)

      # Wait until this promise is complete before running again
      @manager_fiber.transfer(promise)
    end

    def yield
      p = ::Scarpe::Promise.new
      p.fulfilled!
      @manager_fiber.transfer(p)
    end

    # This returns a promise, which can be waited on using wait()
    def fully_updated
      @wrangler.promise_dom_fully_updated
    end

    # Returns a promise that will be fulfilled after the specified number of seconds.
    # Use with wait() to pause test execution while allowing animations/timers to run.
    #
    # @param seconds [Numeric] the number of seconds to wait
    # @return [Scarpe::Promise] a promise that fulfills after the delay
    # @example
    #   wait timed_promise(0.5)  # Wait 500ms
    def timed_promise(seconds)
      promise = ::Scarpe::Promise.new
      @timed_promises << { deadline: Time.now + seconds, promise: promise }
      promise
    end

    def dom_html(timeout: 1.0)
      query_js_value("document.getElementById('wrapper-wvroot').innerHTML", timeout:)
    end

    def query_js_value(js_code, timeout: 1.0)
      js_promise = @wrangler.eval_js_async(js_code, timeout:)

      # This promise will return the string, so we can just pass it to #transfer
      @manager_fiber.transfer(js_promise)
    end

    def query_js_promise(js_code, timeout: 1.0)
      @wrangler.eval_js_async(js_code, timeout:)
    end

    def shut_down_shoes_code
      if @shutdown
        exit 0
      end

      @shutdown = true
      ::Shoes::DisplayService.dispatch_event("destroy", nil)
    end
  end

  # "Cat's Cradle" is a children's game where they interlace string between
  # their fingers to make beautiful complicated shapes. The interlacing
  # of fibers made it a good name for a prototype.
  #
  # An attempt at an experimental Fiber-based control-flow system to deal with
  # Shoes, Display and JS all at the same time.
  #
  # In general, we'll use Fiber.transfer to bounce control back and forth
  # between the evented implementations (e.g. waiting for redraw) that
  # need to return control to Webview, and the procedural test flows
  # that look far better if we don't do that explicitly.
  #
  # Ruby Fiber basic docs: https://ruby-doc.org/core-3.0.0/Fiber.html
  #
  # This module is mixed into an object to coordinate fibers app-wide.
  module CatsCradle
    attr_reader :cc_instance

    def event_init
      @cc_instance ||= CCInstance.instance
      @cc_instance.event_init
    end

    def on_heartbeat(&block)
      @cc_instance.on_event(:next_heartbeat, &block)
    end

    def on_every_heartbeat(&block)
      @cc_instance.on_event(:every_heartbeat, &block)
    end

    def on_init(&block)
      @cc_instance.on_event(:init, &block)
    end

    def on_next_redraw(&block)
      @cc_instance.on_event(:next_redraw, &block)
    end
  end
end
