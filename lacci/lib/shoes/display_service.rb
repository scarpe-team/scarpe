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
module Shoes
  class DisplayService
    class << self
      # This is in the eigenclass/metaclass, *not* instances of DisplayService
      include Shoes::Log

      # An event_target may be nil, to indicate there is no target.
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
      end

      # It's permitted to subscribe to event_name :any for all event names, and event_target :any for all targets.
      # An event_target of nil means "no target", and only matches events dispatched with a nil target.
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

      def unsub_from_events(unsub_id)
        raise "Must provide an unsubscribe ID!" if unsub_id.nil?

        @@display_event_handlers.each do |_e_name, target_hash|
          target_hash.each do |_target, h_list|
            h_list.delete_if { |item| item[:unsub_id] == unsub_id }
          end
        end
      end

      def full_reset!
        @@display_event_handlers = {}
        @json_debug_serialize = nil
      end

      def set_display_service_class(klass)
        raise "Can only set a single display service class!" if @display_service_klass

        @display_service_klass = klass
      end

      def display_service
        return @service if @service

        raise "No display service was set!" unless @display_service_klass

        @service = @display_service_klass.new
      end
    end

    # These methods are an interface to DisplayService objects.

    def create_display_drawable_for(drawable_class_name, drawable_id, properties)
      raise "Override in DisplayService implementation!"
    end

    def set_drawable_pairing(id, display_drawable)
      @display_drawable_for ||= {}
      if @display_drawable_for[id]
        raise DuplicateCreateDrawableError, "There is already a drawable for #{id.inspect}! Not setting a new one."
      end
      @display_drawable_for[id] = display_drawable
    end

    def query_display_drawable_for(id, nil_ok: false)
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
        STDERR.puts "Unsubscribing from event that isn't in subscriptions! #{unsub_id.inspect}"
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
