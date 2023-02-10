# frozen_string_literal: true

# The ControlInterface is used for testing. It's a way to register interest
# in important events like redraw, init and shutdown, and to override
# test-relevant values like the options to Shoes.app(). Note that no part
# of the Scarpe framework should ever *depend* on ControlInterface. It's
# for testing, not normal operation. If no ControlInterface were ever
# created or called, Scarpe apps should run fine with no modifications.
#
# And if you depend on this from the framework, I'll add a check-mode that
# doesn't even create one of these. Do NOT test me on this.

class Scarpe
  class ControlInterface
    EVENTS = [:init, :shutdown, :frame]

    attr_reader :app
    attr_reader :doc_root
    attr_reader :wrangler

    # The control interface needs to see major system components to hook into their events
    def initialize
      @event_handlers = {}
      EVENTS.each { |e| @event_handlers[e] = [] }
    end

    # This should get called once, from Scarpe::App
    def set_system_components(app:, doc_root:, wrangler:)
      @app = app
      @doc_root = doc_root
      @wrangler = wrangler
    end

    # The control interface has overrides for certain settings. If the override has been specified,
    # those settings will be overridden.

    # Override the Shoes app opts like "debug:" and "die_after:" with new ones.
    def override_app_opts(new_opts)
      @new_app_opts = new_opts
    end

    # Called by Scarpe::App to get the override options
    def app_opts_get_override(opts)
      @new_app_opts || opts
    end

    # On recognised events, this sets a handler for that event
    def on_event(event, &block)
      unless EVENTS.include?(event)
        raise "Illegal event #{event.inspect}! Valid values are: #{EVENTS.inspect}"
      end

      @event_handlers[event] << block
    end

    def js_eval(code)
      @wrangler.js_eval(code)
    end

    # Send out the specified event
    def dispatch_event(event, *args, **keywords)
      unless EVENTS.include?(event)
        raise "Illegal event #{event.inspect}! Valid values are: #{EVENTS.inspect}"
      end

      @event_handlers[event].each do |handler|
        instance_eval(*args, **keywords, &handler)
      end
    end
  end
end
