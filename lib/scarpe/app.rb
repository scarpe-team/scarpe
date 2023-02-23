# frozen_string_literal: true

require_relative "control_interface"
require_relative "web_wrangler"

class Scarpe
  class App < Scarpe::Widget
    display_properties :title, :width, :height, :resizable, :debug

    def initialize(title: "Scarpe!", width: 480, height: 420, resizable: true, debug: false, &app_code_body)
      super

      # This creates the DocumentRoot, including its corresponding display widget
      @document_root = Scarpe::DocumentRoot.new(debug: @debug)

      create_display_widget

      @app_code_body = app_code_body
    end

    def init
      send_display_event(event_name: "init")

      @document_root.instance_eval(&@app_code_body)
    end

    # This isn't guaranteed to be able to return. For Webview in particular, this takes control
    # of the main thread ***and*** stops any background threads. TODO: fix that with a second
    # process for Webview.
    def run
      send_display_event(event_name: "run")
    end

    def destroy
      send_display_event(event_name: "destroy")
    end
  end

  # Scarpe::WebviewApp must only be used from the main thread, due to GTK+ limitations.
  class WebviewApp < WebviewWidget
    attr_reader :debug
    attr_reader :control_interface

    attr_writer :shoes_linkable_id

    def initialize(properties)
      super

      # It's possible to provide a Ruby script by setting
      # SCARPE_TEST_CONTROL to its file path. This can
      # allow pre-setting test options or otherwise
      # performing additional actions not written into
      # the Shoes app itself.
      #
      # The control interface is what lets these files see
      # events, specify overrides and so on.
      @control_interface = ControlInterface.new
      if ENV["SCARPE_TEST_CONTROL"]
        @control_interface.instance_eval File.read(ENV["SCARPE_TEST_CONTROL"])
      end

      opts = @control_interface.app_opts_get_override(opts)

      # TODO: rename @view
      @view = Scarpe::WebWrangler.new title: @title, width: @width, height: @height, resizable: @resizable, debug: @debug

      # The control interface has to exist to get callbacks like "override Scarpe app opts".
      # But the Scarpe App needs those options to be created. So we can't pass these to
      # ControlInterface.new.
      @control_interface.set_system_components app: self, doc_root: @document_root, wrangler: @view

      bind_display_event(event_name: "init") { init }
      bind_display_event(event_name: "run") { run }
      bind_display_event(event_name: "destroy") { destroy }
    end

    def document_root=(doc_root)
      @document_root = doc_root
    end

    def init
      scarpe_app = self

      @view.init_code("scarpeInit") do
        redraw_frame
      end

      @view.bind("scarpeHandler") do |*args|
        @document_root.handle_callback(*args)
      end

      @view.bind("scarpeExit") do
        scarpe_app.destroy
      end

      @view.bind("scarpeRedrawCallback") do
        puts("Redraw!") if debug
        redraw_frame if @document_root.redraw_requested
      end
    end

    # Draw a frame, call the per-frame callback(s)
    def redraw_frame
      @view.replace(@document_root.to_html)
      @document_root.clear_needs_update! # We've updated, we don't need to again
      @document_root.end_of_frame
      @control_interface.dispatch_event(:frame)
    end

    def run
      @control_interface.dispatch_event(:init)

      # This takes control of the main thread and never returns. And it *must* be run from
      # the main thread. And it stops any Ruby background threads.
      # That's totally cool and normal, right?
      @view.run
    end

    def js_bind(name, &code)
      raise "Cannot js_bind on closed or inactive Scarpe::App!" unless @view

      @view.bind(name, &code)
    end

    def destroy
      if @document_root || @view
        @control_interface.dispatch_event :shutdown
      end
      @document_root = nil
      if @view
        @view.destroy
        @view = nil
      end
    end
  end
end
