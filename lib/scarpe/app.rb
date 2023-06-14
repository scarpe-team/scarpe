# frozen_string_literal: true

class Scarpe
  class App < Scarpe::Widget
    class << self
      attr_accessor :next_test_code
    end
    include Scarpe::Log

    display_properties :title, :width, :height, :resizable, :debug, :do_shutdown

    def initialize(
      title: "Scarpe!",
      width: 480,
      height: 420,
      resizable: true,
      debug: ENV["SCARPE_DEBUG"] ? true : false,
      test_code: nil,
      &app_code_body
    )
      log_init("Scarpe::App")

      @do_shutdown = false

      if Scarpe::App.next_test_code
        test_code = Scarpe::App.next_test_code
        Scarpe::App.next_test_code = nil
      end

      super

      test_code&.call(self)

      # This creates the DocumentRoot, including its corresponding display widget
      @document_root = Scarpe::DocumentRoot.new

      create_display_widget

      @app_code_body = app_code_body

      Signal.trap("INT") do
        @log.warning("App interrupted by signal, stopping...")
        puts "\nStopping Scarpe app..."
        destroy
      end
    end

    def init
      send_display_event(event_name: "init")
      return if @do_shutdown

      @document_root.instance_eval(&@app_code_body)
    end

    # This isn't guaranteed to be able to return. For Webview in particular, this takes control
    # of the main thread ***and*** stops any background threads.
    #
    # So this is interesting. With a same-process Webview display service, this can't return.
    # Webview takes full control. But we don't want to do that with a "no-op" display service,
    # or no display service at all.
    #
    # If nobody is subscribed to "run", Scarpe will just traipse past "run" into "destroy" and
    # shut everything down.
    def run
      send_display_event(event_name: "run")

      # If there is an assertive display service like Webview, it will take control when
      # it sees the run event and not give it back. A less assertive
      # display service, or none at all, will simply return control immediately,
      # and we'll run our own event loop here.

      # Wait for incoming events from background threads, if any
      until @do_shutdown
        send_display_event(event_name: "heartbeat")
        sleep 0.1
      end
    end

    def destroy
      @do_shutdown = true
      send_display_event(event_name: "destroy")
    end
  end
end
