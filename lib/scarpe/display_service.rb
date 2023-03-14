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
# ## Choosing Display Services
#
# Before running a Scarpe app, you can set SCARPE_DISPLAY_SERVICES. A single
# dash means no display service. A list of class names will cause Scarpe
# to instantiate that class or those classes as the display service(s).
# Leaving the variable unset is equivalent to "Scarpe::WebviewDisplayService".
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

        kwargs[:event_name] = event_name
        kwargs[:event_target] = event_target if event_target
        handlers.each { |h| h[:handler].call(*args, **kwargs) }
      end

      # It's permitted to subscribe to event_name :any for all event names, and event_target :any for all targets.
      # An event_target of nil means "no target", and only matches events dispatched with a nil target.
      def subscribe_to_event(event_type, event_name, event_target, &handler)
        @@display_event_handlers ||= {}
        @@display_event_unsub_id ||= 0
        unless DS_EVENT_TYPES.include?(event_type)
          raise("Unknown event type #{event_type.inspect}! Known types are #{DS_EVENT_TYPES.inspect}!")
        end
        unless handler
          raise "Must pass a block as a handler to DisplayService.subscribe_to_event!"
        end

        id = @@display_event_unsub_id
        @@display_event_unsub_id += 1

        @@display_event_handlers[event_type] ||= {}
        @@display_event_handlers[event_type][event_name] ||= {}
        @@display_event_handlers[event_type][event_name][event_target] ||= []
        @@display_event_handlers[event_type][event_name][event_target] << { handler:, unsub_id: id }

        id
      end

      def unsub_from_events(unsub_id)
        @@display_event_handlers.each do |_type, e_name_hash|
          e_name_hash.each do |_e_name, target_hash|
            target_hash.delete_if { |_target, h_hash| h_hash[:unsub_id] == unsub_id }
          end
        end
      end

      def full_reset!
        @@display_event_handlers = {}
      end

      def display_services
        return @service_list if @service_list

        service_spec = (ENV["SCARPE_DISPLAY_SERVICES"] || "Scarpe::WebviewDisplayService").strip
        if service_spec == "-"
          @service_list = [].freeze
          return @service_list
        end

        @service_list = service_spec.split(";").map do |svc|
          klass = Object.const_get(svc)
          raise "Cannot find class #{svc.inspect} to create display service!" unless klass

          klass.new
        end
      end
    end

    class Linkable
      attr_reader :linkable_id

      def initialize(linkable_id: object_id)
        @linkable_id = linkable_id
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
end
