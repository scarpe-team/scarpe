# frozen_string_literal: true

class Scarpe
  class App < Scarpe::Widget
    include Scarpe::Log

    class << self
      attr_accessor :instance
    end

    attr_reader :document_root

    display_properties :title, :width, :height, :resizable, :debug

    def initialize(
      title: "Scarpe!",
      width: 480,
      height: 420,
      resizable: true,
      debug: ENV["SCARPE_DEBUG"] ? true : false,
      &app_code_body
    )
      log_init("Scarpe::App")

      if Scarpe::App.instance
        @log.error("Trying to create a second Scarpe::App in the same process! Fail!")
        raise "Cannot create multiple Scarpe::App objects!"
      else
        Scarpe::App.instance = self
      end

      @do_shutdown = false

      super

      # This creates the DocumentRoot, including its corresponding display widget
      @document_root = Scarpe::DocumentRoot.new

      # Now create the App display widget
      create_display_widget

      # Set up testing events *after* Display Service basic objects exist
      if ENV["SCARPE_APP_TEST"]
        test_code = File.read ENV["SCARPE_APP_TEST"]
        if test_code != ""
          self.instance_eval test_code
        end
      end

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
      if @do_shutdown
        $stderr.puts "Destroy has already been signaled, but we just called Shoes::App.run!"
        return
      end
      send_shoes_event(event_name: "run")
    end

    def destroy(send_event: true)
      @do_shutdown = true
      send_shoes_event(event_name: "destroy") if send_event
    end
  end
end
