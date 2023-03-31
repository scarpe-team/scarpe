# frozen_string_literal: true

# The ControlInterface is used for testing. It's a way to register interest
# in important events like redraw, init and shutdown, and to override
# test-relevant values like the options to Shoes.app(). Note that no part
# of the Scarpe framework should ever *depend* on ControlInterface. It's
# for testing, not normal operation. If no ControlInterface were ever
# created or called, Scarpe apps should run fine with no modifications.
#
# And if you depend on this from the framework, I'll add a check-mode that
# never dispatches any events to any handlers. Do NOT test me on this.

class Scarpe
  class ControlInterface
    SUBSCRIBE_EVENTS = [:init, :shutdown, :next_redraw, :every_redraw, :next_heartbeat, :every_heartbeat]
    DISPATCH_EVENTS = [:init, :shutdown, :redraw, :heartbeat]

    attr_writer :doc_root

    # The control interface needs to see major system components to hook into their events
    def initialize
      @event_handlers = {}
      (SUBSCRIBE_EVENTS | DISPATCH_EVENTS).each { |e| @event_handlers[e] = [] }
    end

    def inspect
      "<#ControlInterface>"
    end

    # This should get called once, from Scarpe::App
    def set_system_components(app:, doc_root:, wrangler:)
      unless app && wrangler
        puts "app is false!" unless app
        puts "wrangler is false!" unless wrangler
        raise "Must pass non-nil app and wrangler to ControlInterface#set_system_components!"
      end
      @app = app
      @doc_root = doc_root # May be nil at this point
      @wrangler = wrangler

      @wrangler.control_interface = self

      @wrangler.on_every_redraw { self.dispatch_event(:redraw) }
    end

    def app
      unless @app
        raise "ControlInterface code needs to be wrapped in handlers like on_event(:init) " +
          "to make sure they have access to app, doc_root, wrangler, etc!"
      end

      @app
    end

    def doc_root
      unless @doc_root
        raise "ControlInterface code needs to be wrapped in handlers like on_event(:init) " +
          "to make sure they have access to app, doc_root, wrangler, etc!"
      end

      @doc_root
    end

    def wrangler
      unless @wrangler
        raise "ControlInterface code needs to be wrapped in handlers like on_event(:init) " +
          "to make sure they have access to app, doc_root, wrangler, etc!"
      end

      @wrangler
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
      unless SUBSCRIBE_EVENTS.include?(event)
        raise "Illegal subscribe to event #{event.inspect}! Valid values are: #{SUBSCRIBE_EVENTS.inspect}"
      end

      @event_handlers[event] << block
    end

    # Send out the specified event
    def dispatch_event(event, *args, **keywords)
      unless DISPATCH_EVENTS.include?(event)
        raise "Illegal dispatch of event #{event.inspect}! Valid values are: #{DISPATCH_EVENTS.inspect}"
      end

      if event == :redraw
        dumb_dispatch_event(:every_redraw, *args, **keywords)

        # Next redraw is interesting. We can add new handlers
        # when dispatching a next_redraw handler. But we want
        # each handler to run only once.
        handlers = @event_handlers[:next_redraw]
        dumb_dispatch_event(:next_redraw, *args, **keywords)
        @event_handlers[:next_redraw] -= handlers
        return
      end

      if event == :heartbeat
        dumb_dispatch_event(:every_heartbeat, *args, **keywords)

        # Next heartbeat is interesting. We can add new handlers
        # when dispatching a next_heartbeat handler. But we want
        # each handler to run only once.
        handlers = @event_handlers[:next_heartbeat]
        dumb_dispatch_event(:next_heartbeat, *args, **keywords)
        @event_handlers[:next_heartbeat] -= handlers
        return
      end

      dumb_dispatch_event(event, *args, **keywords)
    end

    private

    def dumb_dispatch_event(event, *args, **keywords)
      @event_handlers[event].each do |handler|
        instance_eval(*args, **keywords, &handler)
      end
    end
  end
end
