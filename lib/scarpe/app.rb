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
end
