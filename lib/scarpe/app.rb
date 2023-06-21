# frozen_string_literal: true

class Scarpe
  class App < Scarpe::Widget
    class << self
      attr_accessor :next_test_code
    end
    include Scarpe::Log

    display_properties :title, :width, :height, :resizable, :debug

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

      # Try to de-dup as much as possible and not send repeat or multiple
      # destroy events
      @watch_for_destroy = bind_shoes_event(event_name: "destroy") do
        DisplayService.unsub_from_events(@watch_for_destroy) if @watch_for_destroy
        @watch_for_destroy = nil
        self.destroy(send_event: false)
      end

      Signal.trap("INT") do
        @log.warning("App interrupted by signal, stopping...")
        puts "\nStopping Scarpe app..."
        destroy
      end
    end

    def init
      send_shoes_event(event_name: "init")
      return if @do_shutdown

      @document_root.instance_eval(&@app_code_body)
    end

    # This isn't supposed to return. The display service should take control
    # of the main thread. Local Webview even stops any background threads.
    def run
      send_shoes_event(event_name: "run")
    end

    def destroy(send_event: true)
      @do_shutdown = true
      send_shoes_event(event_name: "destroy") if send_event
    end
  end
end
