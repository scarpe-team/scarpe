# frozen_string_literal: true

require "scarpe/components/unit_test_helpers"
require "scarpe/evented_assertions"

require "fiber"

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
module Scarpe::Test
  # We'd like something we can call Shoes widget methods on, such as para.replace.
  # But we'd also like to be able to grab the corresponding display widget and
  # call some of *those* methods.
  class CCProxy
    attr_reader :display
    attr_reader :obj

    def initialize(obj)
      @obj = obj
      # TODO: how to do this with Webview relay? Proxy object to send a message, maybe?
      @display = ::Shoes::DisplayService.display_service.query_display_widget_for(obj.linkable_id)
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

  # This class defines the CatsCradle DSL. It also holds a "bag of fibers"
  # with promises for when they should next resume.
  class CCInstance
    include Shoes::Log
    include Scarpe::Test::EventedAssertions
    include Scarpe::Test::Helpers

    def self.instance
      @instance ||= CCInstance.new
    end

    def initialize
      log_init("CatsCradle")

      @assertion_data = []
      @assertions_passed = 0
      @assertions_failed = []

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
              raise "Unexpected object returned from Fiber#transfer for still-living Fiber! #{result.inspect}"
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
    EVENT_TYPES = [:next_heartbeat, :next_redraw]

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
      raise "Unknown event type: #{event.inspect}!" unless EVENT_TYPES.include?(event)

      f = Fiber.new do
        CCInstance.instance.instance_eval(&block)
      end
      @waiting_fibers << { promise: event_promise(event), fiber: f }
    end

    # What to do about TextWidgets? Link, code, em, strong?
    # Also, wait, what's up with span? What *is* that?
    Shoes::Widget.widget_classes.each do |widget_class|
      finder_name = widget_class.dsl_name

      define_method(finder_name) do |*args|
        app = Shoes::App.instance

        widgets = app.find_widgets_by(widget_class, *args)
        raise "Found more than one #{finder_name} matching #{args.inspect}!" if widgets.size > 1
        raise "Found no #{finder_name} matching #{args.inspect}!" if widgets.empty?

        CCProxy.new(widgets[0])
      end
    end

    def proxy_for(shoes_widget)
      CCProxy.new(shoes_widget)
    end

    def wait(promise)
      raise("Must supply a promise to wait!") unless promise.is_a?(::Scarpe::Promise)

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

    def assert(value, msg = nil)
      msg ||= "Assertion #{value ? "succeeded" : "failed"}"
      @assertion_data << [value ? true : false, msg]
      if value
        @assertions_passed += 1
      else
        @assertions_failed << msg
      end
    end

    def assert_equal(expected, actual, msg = nil)
      msg ||= "Expected #{actual.inspect} to equal #{expected.inspect}!"
      assert actual == expected, msg
    end

    def assertion_data_as_a_struct
      {
        still_pending: 0,
        succeeded: @assertions_passed,
        failed: @assertions_failed.size,
        failures: @assertions_failed,
      }
    end

    def test_metadata
      {}
    end

    def test_finished
      if !@assertions_failed.empty?
        return_results(false, "Assertions failed", assertion_data_as_a_struct)
      elsif @assertions_passed > 0
        return_results(true, "All assertions passed", assertion_data_as_a_struct)
      else
        return_results(true, "Test finished successfully")
      end
      ::Shoes::DisplayService.dispatch_event("destroy", nil)
    end
  end

  # This module is mixed into Shoes::App if we're running CC-based tests
  module CatsCradle
    def event_init
      @cc_instance = CCInstance.instance
      @cc_instance.event_init
    end

    def on_heartbeat(&block)
      @cc_instance.on_event(:next_heartbeat, &block)
    end
  end
end
