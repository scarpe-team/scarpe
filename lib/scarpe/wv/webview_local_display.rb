# frozen_string_literal: true

class Scarpe
  # This is an in-process Webview-based display service, with all the limitations that
  # entails. Slow handlers will crash, ending this display service will end the
  # process, too many or too large evals can crash the process, etc.
  # Normally the intention is to use a RelayDisplayService to a second
  # process containing one of these.
  class WebviewDisplayService < Shoes::DisplayService
    include Scarpe::Log

    class << self
      attr_accessor :instance
    end

    # TODO: re-think the list of top-level singleton objects.
    attr_reader :control_interface
    attr_reader :doc_root
    attr_reader :app
    attr_reader :wrangler

    # This is called before any of the various WebviewWidgets are created.
    def initialize
      if WebviewDisplayService.instance
        raise "ERROR! This is meant to be a singleton!"
      end

      WebviewDisplayService.instance = self

      super()
      log_init("WV::WebviewDisplayService")

      @display_widget_for = {}
    end

    def create_display_widget_for(widget_class_name, widget_id, properties)
      if widget_class_name == "App"
        unless @doc_root
          raise "WebviewDocumentRoot is supposed to be created before WebviewApp!"
        end

        display_app = Scarpe::WebviewApp.new(properties)
        display_app.document_root = @doc_root
        @control_interface = display_app.control_interface
        @control_interface.doc_root = @doc_root
        @app = @control_interface.app
        @wrangler = @control_interface.wrangler

        set_widget_pairing(widget_id, display_app)

        return display_app
      end

      # Create a corresponding display widget
      display_class = Scarpe::WebviewWidget.display_class_for(widget_class_name)
      display_widget = display_class.new(properties)
      set_widget_pairing(widget_id, display_widget)

      if widget_class_name == "DocumentRoot"
        # WebviewDocumentRoot is created before WebviewApp. Mostly doc_root is just like any other widget,
        # but we'll want a reference to it when we create WebviewApp.
        @doc_root = display_widget
      end

      display_widget
    end

    def destroy
      @app.destroy
      WebviewDisplayService.instance = nil
    end
  end
end
