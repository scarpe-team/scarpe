# frozen_string_literal: true

# Scarpe Shoes apps operate in multiple layers. A Shoes widget tree exists as fairly
# plain, simple Ruby objects. And then a display-service widget tree integrates with
# the display technology, initially Webview. This lets us use Ruby as our API while
# not tying it too closely to some fairly serious limitations of Webview.
# Scarpe widgets *expect* to operate in a fairly "hands off" mode where they record
# to an event queue to send to the display service, and the display service records
# events to send back.
#
# When a Shoes handler takes an action (e.g. some_para.replace(),) the relevant
# call will be dispatched as a :display event, to be sent to the display service.
# And when a display-side event occurs (e.g. user pushes a button,) it will be
# dispatched as a :shoes event, to be sent to the Shoes tree of widgets.
#
# It is normally assumed that there will only be a single 'real' consumer for each
# queue. You wouldn't usually want multiple display services sending back click
# events, for example. But that's not a technical limitation of the system.
# You could have no display service and not get any events back, or a debug
# display service that just records what happened. But in real situations,
# exactly one display service is a reasonable and appropriate assumption.
#
# The event types are "queues" in the sense that they're separate from each
# other. You need to subscribe separately to :shoes and :display events if
# you want both. But internally they're immediately dispatched as events
# rather than keeping a literal array of items.
#
class Scarpe
  class DisplayService
    DS_EVENT_TYPES = [:shoes, :display]

    class << self
      # An event_target may be nil, to indicate there is no target.
      def dispatch_event(event_type, event_name, event_target, *args, **kwargs)
        @@display_event_handlers ||= {}
        unless DS_EVENT_TYPES.include?(event_type)
          raise("Unknown event type #{event_type.inspect}! Known types are #{DS_EVENT_TYPES.inspect}!")
        end

        raise "Cannot dispatch on event_name :any!" if event_name == :any

        # TODO: debug mode that JSON-serializes and -deserializes all args to make sure only legal
        # objects are passed through.

        same_type_handlers = @@display_event_handlers[event_type] || {}
        return if same_type_handlers.empty?

        same_name_handlers = same_type_handlers[event_name] || {}
        any_name_handlers = same_type_handlers[:any] || {}

        # Do we have any keys, in same_name_handlers or any_name_handlers, matching the target or :any?
        # Note that "nil" is a target like any other for these purposes -- subscribing to a nil target
        # won't get you non-nil-target events and vice-versa.
        handlers = [
          same_name_handlers[:any],           # Same name, any target
          same_name_handlers[event_target],   # Same name, same target
          any_name_handlers[:any],            # Any name, any target
          any_name_handlers[event_target],    # Any name, same target
        ].compact.inject([], &:+)

        handlers.each { |h| h.call(*args, **kwargs) }
      end

      # It's permitted to subscribe to event_name :any for all event names, and event_target :any for all targets.
      # An event_target of nil means "no target", and only matches events dispatched with a nil target.
      def subscribe_to_event(event_type, event_name, event_target, &handler)
        @@display_event_handlers ||= {}
        unless DS_EVENT_TYPES.include?(event_type)
          raise("Unknown event type #{event_type.inspect}! Known types are #{DS_EVENT_TYPES.inspect}!")
        end
        unless handler
          raise "Must pass a block as a handler to DisplayService.subscribe_to_event!"
        end

        @@display_event_handlers[event_type] ||= {}
        @@display_event_handlers[event_type][event_name] ||= {}
        @@display_event_handlers[event_type][event_name][event_target] ||= []
        @@display_event_handlers[event_type][event_name][event_target] << handler
      end

      # TODO: add more display service types, use an env var to switch
      def display_services
        @service_list ||= [WebviewDisplayService.new]
      end
    end

    class Linkable
      attr_reader :linkable_id

      def initialize(linkable_id: object_id)
        @linkable_id = linkable_id
      end

      # A Scarpe::Widget can filter out non-display properties, or set default values, before they get
      # sent to the display side. That way there's no need to update two sets of default values for
      # a field -- the Shoes-side values can have defaults and options, while the display side
      # property list is complete and final.
      def display_widget_properties(*args, **kwargs)
        if block_given?
          raise "display_widget_properties does not take a block!" +
            " Shoes-side blocks run in Shoes, not the display service!"
        end

        # We want to support multiple, or zero, display services later. Thus, we link via events and
        # DisplayService objects.
        DisplayService.display_services.each do |display_service|
          # We DO NOT save a reference to our display widget(s). If they just disappear later, we'll cheerfully
          # keep ticking along and not complain.
          display_service.create_display_widget_for(self, *args, **kwargs)
        end
      end

      def send_shoes_event(*args, event_name:, target: nil, **kwargs)
        DisplayService.dispatch_event(:shoes, event_name, target, *args, **kwargs)
      end

      def send_display_event(*args, event_name:, target: nil, **kwargs)
        DisplayService.dispatch_event(:display, event_name, target, *args, **kwargs)
      end

      def bind_shoes_event(event_name:, target: nil, &handler)
        DisplayService.subscribe_to_event(:shoes, event_name, target, &handler)
      end

      def bind_display_event(event_name:, target: nil, &handler)
        DisplayService.subscribe_to_event(:display, event_name, target, &handler)
      end
    end
  end

  class WebviewDisplayService
    class << self
      attr_accessor :instance
    end

    # TODO: re-think the list of top-level singleton objects.
    attr_reader :control_interface
    attr_reader :app
    attr_reader :doc_root
    attr_reader :wrangler

    # This is called before any of the various WebviewWidgets are created.
    def initialize
      if WebviewDisplayService.instance
        raise "ERROR! This is meant to be a singleton!"
      end

      WebviewDisplayService.instance = self

      @display_widget_for = {}
    end

    def create_display_widget_for(widget, *args, **kwargs)
      klass = widget.class
      # Initial app creation seems like a mess of special cases right now. It would be nice to clean it up.

      if klass == Scarpe::App
        unless @doc_root
          raise "WebviewDocumentRoot is supposed to be created before WebviewApp!"
        end

        display_app = Scarpe::WebviewApp.new(
          *args,
          shoes_linkable_id: widget.linkable_id,
          document_root: @doc_root,
**kwargs,
        )
        @control_interface = display_app.control_interface
        @app = @control_interface.app
        @wrangler = @control_interface.wrangler

        set_widget_pairing(widget, display_app)

        return display_app
      end

      # Create a corresponding display widget
      display_class = Scarpe::WebviewWidget.display_class_for(klass)
      display_widget = display_class.new(*args, shoes_linkable_id: widget.linkable_id, **kwargs)
      set_widget_pairing(widget, display_widget)

      if widget.parent
        $stderr.puts "We assumed there was no widget parent yet. Fix this?"
      end

      if klass == Scarpe::DocumentRoot
        # WebviewDocumentRoot is created before WebviewApp. Mostly doc_root is just like any other widget,
        # but we'll want a reference to it when we create WebviewApp.
        @doc_root = display_widget
      end

      display_widget
    end

    def set_widget_pairing(widget, display_widget)
      @display_widget_for[widget.linkable_id] = display_widget
    end

    def query_display_widget_for(id, nil_ok: false)
      display_widget = @display_widget_for[id]
      unless display_widget || nil_ok
        raise "Could not find display widget for linkable ID #{id.inspect}!"
      end

      display_widget
    end
  end
end
