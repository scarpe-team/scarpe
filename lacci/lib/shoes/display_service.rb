# frozen_string_literal: true

# Lacci Shoes apps operate in multiple layers. A Shoes drawable tree exists as fairly
# plain, simple Ruby objects. And then a display-service drawable tree integrates with
# the display technology. This lets us use Ruby as our API while
# not tying it too closely to the limitations of Webview, WASM, LibUI, etc.
#
# ## Choosing Display Services
#
# Before running a Lacci app, you can set SCARPE_DISPLAY_SERVICE. If you
# set it to "whatever_service", Scarpe will require "scarpe/whatever_service",
# which can be supplied by the Scarpe gem or another Scarpe-based gem.
# Currently leaving the environment variable empty is equivalent to requesting
# local Webview.
#
# ## Events
#
# Events are a lot of what tie the Shoes drawables and the display service together.
#
# Shoes drawables *expect* to operate in a fairly "hands off" mode where they record
# to an event queue to send to the display service, and the display service records
# events to send back.
#
# When a Shoes handler takes an action (e.g. some_para.replace(),) the relevant
# call will be dispatched as a :display event, to be sent to the display service.
# And when a display-side event occurs (e.g. user pushes a button,) it will be
# dispatched as a :shoes event, to be sent to the Shoes tree of drawables.
#
class Shoes
  class DisplayService
    class << self
      # This is in the eigenclass/metaclass, *not* instances of DisplayService
      include Shoes::Log

      # Global mouse state: [button, x, y]
      # Updated by the display service, read by App#mouse.
      # button: 1 if left mouse button is held, 0 otherwise
      def mouse_state
        @mouse_state || [0, 0, 0]
      end

      attr_writer :mouse_state

      # Builtin response mechanism: allows display service handlers to return
      # values to the Shoes-side caller (e.g. ask, confirm, clipboard).
      # The handler calls set_builtin_response(value) during synchronous dispatch,
      # and the caller reads it via consume_builtin_response after dispatch returns.
      def set_builtin_response(value)
        @builtin_response = value
        @has_builtin_response = true
      end

      def consume_builtin_response
        if @has_builtin_response
          @has_builtin_response = false
          result = @builtin_response
          @builtin_response = nil
          result
        else
          nil
        end
      end

      def clear_builtin_response
        @has_builtin_response = false
        @builtin_response = nil
      end

      # Send a Shoes event to all subscribers.
      # An event_target may be nil, to indicate there is no target.
      #
      # @param event_name [String] the name of the event
      # @param event_target [String] the specific target, if any
      # @param args [Array] arguments to pass to the subscribing block
      # @param args [Array] keyword arguments to pass to the subscribing block
      # @return [void]
      def dispatch_event(event_name, event_target, *args, **kwargs)
        @@display_event_handlers ||= {}

        unless @log
          log_init("DisplayService")
        end

        raise "Cannot dispatch on event_name :any!" if event_name == :any

        @log.debug("Dispatch event: #{event_name.inspect} T: #{event_target.inspect} A: #{args.inspect} KW: #{kwargs.inspect}")

        # When true, this makes sure all events and properties are 100% strings, no symbols.
        if ENV["SCARPE_DEBUG"]
          args = JSON.parse JSON.dump(args)
          new_kw = {}
          kwargs.each do |k, v|
            new_kw[k] = JSON.parse JSON.dump(v)
          end
          kwargs = new_kw
        end

        same_name_handlers = @@display_event_handlers[event_name] || {}
        any_name_handlers = @@display_event_handlers[:any] || {}

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
        nil
      end

      # Subscribe to the given event name and target.
      # It's permitted to subscribe to event_name :any for all event names,
      # and event_target :any for all targets. An event_target of nil means
      # "no target", and only matches events dispatched with a nil target.
      # The subscription will return an unsubscribe ID, which can be used
      # later to unsubscribe from the notification.
      #
      # @param event_name [String,Symbol] the event name to subscribe to, or :any for all event names
      # @param event_target [String,Symbol,NilClass] the event target to subscribe to, or :any for all targets - nil is a valid target
      # @block the block to call when the event occurs - it will receive arguments from the event-dispatch call
      # @return [Integer] an unsubscription ID which can be used later to cancel the subscription
      def subscribe_to_event(event_name, event_target, &handler)
        @@display_event_handlers ||= {}
        @@display_event_unsub_id ||= 0
        unless handler
          raise "Must pass a block as a handler to DisplayService.subscribe_to_event!"
        end

        unless @log
          log_init("DisplayService")
        end

        @log.debug("Subscribe to event: #{event_name.inspect} T: #{event_target.inspect}")

        id = @@display_event_unsub_id
        @@display_event_unsub_id += 1

        @@display_event_handlers[event_name] ||= {}
        @@display_event_handlers[event_name][event_target] ||= []
        @@display_event_handlers[event_name][event_target] << { handler:, unsub_id: id }

        id
      end

      # Unsubscribe from any event subscriptions matching the unsub ID.
      #
      # @param unsub_id [Integer] the unsub ID returned when subscribing
      # @return [void]
      def unsub_from_events(unsub_id)
        raise "Must provide an unsubscribe ID!" if unsub_id.nil?

        @@display_event_handlers.each do |_e_name, target_hash|
          target_hash.each do |_target, h_list|
            h_list.delete_if { |item| item[:unsub_id] == unsub_id }
          end
        end
      end

      # Reset the display service, for instance between unit tests.
      # This destroys all existing subscriptions.
      #
      # @return [void]
      def full_reset!
        @@display_event_handlers = {}
        @json_debug_serialize = nil
      end

      # Set the Display Service class which will handle display service functions
      # for this process. This can only be set once. The display service can be
      # a subclass of Shoes::DisplayService, but isn't required to be.
      #
      # Shoes will create an instance of this class with no arguments passed to
      # initialize, and use it as the display service for the lifetime of the
      # process.
      #
      # @param klass [Class] the class for the display service
      def set_display_service_class(klass)
        raise "Can only set a single display service class!" if @display_service_klass

        @display_service_klass = klass
      end

      # Get the current display service instance. This requires a display service
      # class having been set first. @see set_display_service_class
      def display_service
        return @service if @service

        raise "No display service was set!" unless @display_service_klass

        @service = @display_service_klass.new
      end
    end

    def initialize
      @display_drawable_for = {}
    end

    # These methods are an interface to DisplayService objects.

    def create_display_drawable_for(drawable_class_name, drawable_id, properties, parent_id:, is_widget:)
      raise "Override in DisplayService implementation!"
    end

    def set_drawable_pairing(id, display_drawable)
      if id.nil?
        raise Shoes::Errors::BadLinkableIdError, "Linkable ID may not be nil!"
      end

      @display_drawable_for ||= {}
      if @display_drawable_for[id]
        raise Shoes::Errors::DuplicateCreateDrawableError, "There is already a drawable for #{id.inspect}! Not setting a new one."
      end

      @display_drawable_for[id] = display_drawable
      nil
    end

    def query_display_drawable_for(id, nil_ok: false)
      @display_drawable_for ||= {}
      display_drawable = @display_drawable_for[id]
      unless display_drawable || nil_ok
        raise "Could not find display drawable for linkable ID #{id.inspect}!"
      end

      display_drawable
    end

    def destroy
      raise "Override in DisplayService implementation!"
    end
  end

  # This is for objects that can be referred to via events, using their
  # IDs. There are also convenience functions for binding and sending
  # events.
  #
  # Linkable objects may be event targets. Technically anything, linkable
  # or not, can be an event subscriber, but linkables get easy convenience
  # functions for subscription.
  class Linkable
    attr_reader :linkable_id

    def initialize(linkable_id: object_id)
      @linkable_id = linkable_id
      @subscriptions = {}
    end

    def send_self_event(*args, event_name:, **kwargs)
      DisplayService.dispatch_event(event_name, self.linkable_id, *args, **kwargs)
    end

    def send_shoes_event(*args, event_name:, target: nil, **kwargs)
      DisplayService.dispatch_event(event_name, target, *args, **kwargs)
    end

    def bind_shoes_event(event_name:, target: nil, &handler)
      sub = DisplayService.subscribe_to_event(event_name, target, &handler)
      @subscriptions[sub] = true
      sub
    end

    def unsub_shoes_event(unsub_id)
      unless @subscriptions[unsub_id]
        $stderr.puts "Unsubscribing from event that isn't in subscriptions! #{unsub_id.inspect}"
      end
      DisplayService.unsub_from_events(unsub_id)
      @subscriptions.delete unsub_id
    end

    def unsub_all_shoes_events
      @subscriptions.keys.each { |k| DisplayService.unsub_from_events(k) }
      @subscriptions.clear
    end
  end
end
