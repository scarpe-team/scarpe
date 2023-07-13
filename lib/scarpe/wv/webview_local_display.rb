# frozen_string_literal: true

class Scarpe
  # This is the simplest type of Webview DisplayService. It creates Webview widgets
  # corresponding to Shoes widgets, manages the Webview and its DOM tree, and
  # generally keeps the Shoes/Webview connection working.
  #
  # This is an in-process Webview-based display service, with all the limitations that
  # entails. Slow handlers will crash, ending this display service will end the
  # process, too many or too large evals can crash the process, etc.
  # Frequently it's better to use a RelayDisplayService to a second
  # process containing one of these.
  class WebviewDisplayService < Shoes::DisplayService
    include Scarpe::Log

    class << self
      attr_accessor :instance
    end

    # The ControlInterface is used to handle internal events in Webview Scarpe
    attr_reader :control_interface

    # The DocumentRoot is the top widget of the Webview-side widget tree
    attr_reader :doc_root

    # app is the Scarpe::WebviewApp
    attr_reader :app

    # wrangler is the Scarpe::WebWrangler
    attr_reader :wrangler

    # This is called before any of the various WebviewWidgets are created, to be
    # able to create them and look them up.
    def initialize
      if WebviewDisplayService.instance
        raise "ERROR! This is meant to be a singleton!"
      end

      WebviewDisplayService.instance = self

      super()
      log_init("WV::WebviewDisplayService")

      @display_widget_for = {}
    end

    # Create a Webview display widget for a specific Shoes widget, and pair it with
    # the linkable ID for this Shoes widget.
    #
    # @param widget_class_name [String] The class name of the Shoes widget, e.g. Shoes::Button
    # @param widget_id [String] the linkable ID for widget events
    # @param properties [Hash] a JSON-serialisable Hash with the widget's display properties
    # @return [WebviewWidget] the newly-created Webview widget
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

    # Destroy the display service and the app. Quit the process (eventually.)
    #
    # @return [void]
    def destroy
      @app.destroy
      WebviewDisplayService.instance = nil
    end
  end
end
