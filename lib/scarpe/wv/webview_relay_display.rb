# frozen_string_literal: true

require "socket"
require "rbconfig"

require_relative "webview_relay_util"

class Scarpe
  # This display service creates a child process and sends events
  # back and forth, but creates no widgets of its own. The child
  # process will spawn a worker with its own Webview::DisplayService
  # where the real Webview exists. By splitting the Webview
  # process from the Shoes widgets, it can be easier to return
  # control to Webview's event handler promptly. Also, the Ruby
  # process could run background threads if it wanted, and
  # otherwise behave like a process ***not*** containing Webview.
  class Webview::RelayDisplayService < Shoes::DisplayService
    include Shoes::Log
    include WVRelayUtil # Needs Shoes::Log

    attr_accessor :shutdown

    # Create a Webview Relay Display Service
    def initialize
      super()
      log_init("Webview::RelayDisplayService")

      @event_subs = []
      @shutdown = false
      @i_am = :parent

      server = TCPServer.new("127.0.0.1", 0)
      port = server.addr[1]

      @pid = spawn(RbConfig.ruby, File.join(__dir__, "wv_display_worker.rb"), port.to_s)
      @from = @to = server.accept

      # Subscribe to all event notifications and relay them to the worker
      @event_subs << bind_shoes_event(event_name: :any, target: :any) do |*args, **kwargs|
        unless kwargs[:relayed]
          kwargs[:relayed] = true
          send_datagram({ type: :event, args:, kwargs: })
        end

        # Forward the run event to the child process before doing this
        if event_name == "run"
          run_event_loop
        end
      rescue AppShutdownError
        @shutdown = true
        @log.info("Attempting to shut down...")
        self.destroy
      end
    end

    # Run, sending and responding to datagrams continuously.
    def run_event_loop
      until @shutdown
        respond_to_datagram while ready_to_read?
        sleep 0.1
      end
    rescue AppShutdownError
      @shutdown = true
      @log.info("Attempting to shut down...")
      self.destroy
    end

    # This method sends a message to the worker process to create a widget. No actual
    # widget is created or registered with the display service.
    def create_display_widget_for(widget_class_name, widget_id, properties)
      send_datagram({ type: :create, class_name: widget_class_name, id: widget_id, properties: })
      # Don't need to return anything. It wouldn't be used anyway.
    end

    # Tell the worker process to quit, and set a flag telling the event loop to shut down.
    def destroy
      unless @shutdown
        send_datagram({ type: :destroy })
      end
      @shutdown = true
      (@events_subs || []).each { |unsub_id| DisplayService.unsub_from_events(unsub_id) }
    end
  end
end
