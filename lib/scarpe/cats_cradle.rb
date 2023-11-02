# frozen_string_literal: true

require "scarpe/components/unit_test_helpers"
require "scarpe/evented_assertions"

require "fiber"

module Scarpe::Test
  # We'd like something we can call Shoes drawable methods on, such as para.replace.
  # But we'd also like to be able to grab the corresponding display drawable and
  # call some of *those* methods.
  class CCProxy
    attr_reader :display
    attr_reader :obj

    def initialize(obj)
      @obj = obj
      # TODO: how to do this with Webview relay? Proxy object to send a message, maybe?
      @display = ::Shoes::DisplayService.display_service.query_display_drawable_for(obj.linkable_id)
    end

    def method_missing(method, ...)
      if @obj.respond_to?(method)
        self.singleton_class.define_method(method) do |*args, **kwargs, &block|
          @obj.send(method, *args, **kwargs, &block)
        end
        send(method, ...)
      else
        super # raise an exception
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @obj.respond_to_missing?(method_name, include_private)
    end
  end

  module DrawableFinders
    # What to do about TextDrawables? Link, code, em, strong?
    # Also, wait, what's up with span? What *is* that?
    Shoes::Drawable.drawable_classes.each do |drawable_class|
      finder_name = drawable_class.dsl_name

      define_method(finder_name) do |*args|
        app = Shoes::App.instance

        drawables = app.find_drawables_by(drawable_class, *args)
        raise Scarpe::MultipleDrawablesFoundError, "Found more than one #{finder_name} matching #{args.inspect}!" if drawables.size > 1
        raise Scarpe::NoDrawablesFoundError, "Found no #{finder_name} matching #{args.inspect}!" if drawables.empty?

        CCProxy.new(drawables[0])
      end
    end
  end

  # This class defines the CatsCradle DSL. It also holds a "bag of fibers"
  # with promises for when they should next resume.
  class CCInstance
    include Shoes::Log
    include Scarpe::Test::EventedAssertions
    include Scarpe::Test::Helpers
    include Scarpe::Test::DrawableFinders

    def self.instance
      @instance ||= CCInstance.new
    end

    def initialize
      log_init("CatsCradle")

      evented_assertions_initialize

      @waiting_fibers = []
      @event_promises = {}

      @manager_fiber = Fiber.new do
        loop do
          # A fiber can run briefly and then exit. It can run and then block on an API call.
          # These fibers return promises to indicate to CatsCradle when they can run again.
          # A fiber that is no longer #alive? is assumed to be successfully finished.
          @waiting_fibers.each do |fiber_data|
            next unless fiber_data[:promise].fulfilled?

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

    # If we add "every" events, that's likely to complicate timing and event_promise handling.
    EVENT_TYPES = [:init, :next_heartbeat, :next_redraw]

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

          # Give every ready fiber a chance to run once.
          @manager_fiber.resume
        end
      end

      @control_interface.on_event(:every_redraw) do
        cc_instance.instance_eval do
          p = @event_promises.delete(:next_redraw)
          p&.fulfilled!

          # Give every ready fiber a chance to run once.
          @manager_fiber.resume
        end
      end
    end

    def event_promise(event)
      @event_promises[event] ||= ::Scarpe::Promise.new
    end

    def on_event(event, &block)
      raise Scarpe::UnknownEventTypeError, "Unknown event type: #{event.inspect}!" unless EVENT_TYPES.include?(event)

      f = Fiber.new do
        CCInstance.instance.instance_eval(&block)
      end
      @waiting_fibers << { promise: event_promise(event), fiber: f }
    end

    def proxy_for(shoes_drawable)
      CCProxy.new(shoes_drawable)
    end

    def die_after(time)
      t_start = Time.now
      @die_after = [t_start, time]

      @wrangler.periodic_code("scarpeTestTimeout") do |*_args|
        t_delta = (Time.now - t_start).to_f
        if t_delta > time
          @did_time_out = true
          @log.warn("die_after - timed out after #{t_delta.inspect} (threshold: #{time.inspect})")
          return_results(false, "Timed out!")
          ::Shoes::DisplayService.dispatch_event("destroy", nil)
        end
      end
    end

    def wait(promise)
      raise(Scarpe::InvalidPromiseError, "Must supply a promise to wait!") unless promise.is_a?(::Scarpe::Promise)

      # Wait until this promise is complete before running again
      @manager_fiber.transfer(promise)
    end

    # This returns a promise, which can be waited on using wait()
    def fully_updated
      @wrangler.promise_dom_fully_updated
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

    def test_finished(return_results: true)
      return_assertion_data if return_results

      ::Shoes::DisplayService.dispatch_event("destroy", nil)
    end

    def test_finished_no_results
      ::Shoes::DisplayService.dispatch_event("destroy", nil)
    end
  end

  # "Cat's Cradle" is a children's game where they interlace string between
  # their fingers to make beautiful complicated shapes. The interlacing
  # of fibers made it a good name for a prototype.

  # An attempt at an experimental Fiber-based testing system to deal with
  # Shoes, Display and JS all at the same time.
  #
  # In general, we'll use Fiber.transfer to bounce control back and forth
  # between the evented implementations (e.g. waiting for redraw) that
  # need to return control to Webview, and the procedural test flows
  # that look far better if we don't do that explicitly.
  #
  # Ruby Fiber basic docs: https://ruby-doc.org/core-3.0.0/Fiber.html
  #
  # This module is mixed into a test object if we're running CatsCradle-based tests
  module CatsCradle
    def event_init
      @cc_instance ||= CCInstance.instance
      @cc_instance.event_init
    end

    def on_heartbeat(&block)
      @cc_instance.on_event(:next_heartbeat, &block)
    end

    def on_init(&block)
      @cc_instance.on_event(:init, &block)
    end

    def on_next_redraw(&block)
      @cc_instance.on_event(:next_redraw, &block)
    end
  end
end
