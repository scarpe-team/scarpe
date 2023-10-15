# frozen_string_literal: true

module Scarpe
  # This is the simplest type of Webview DisplayService. It creates Webview drawables
  # corresponding to Shoes drawables, manages the Webview and its DOM tree, and
  # generally keeps the Shoes/Webview connection working.
  #
  # This is an in-process Webview-based display service, with all the limitations that
  # entails. Slow handlers will crash, ending this display service will end the
  # process, too many or too large evals can crash the process, etc.
  # Frequently it's better to use a RelayDisplayService to a second
  # process containing one of these.
  class Webview::DisplayService < Shoes::DisplayService
    include Shoes::Log

    class << self
      attr_accessor :instance
    end

    # The ControlInterface is used to handle internal events in Webview Scarpe
    attr_reader :control_interface

    # The DocumentRoot is the top drawable of the Webview-side drawable tree
    attr_reader :doc_root

    # app is the Scarpe::Webview::App
    attr_reader :app

    # wrangler is the Scarpe::WebWrangler
    attr_reader :wrangler

    # This is called before any of the various Webview::Drawables are created, to be
    # able to create them and look them up.
    def initialize
      if Webview::DisplayService.instance
        raise Scarpe::SingletonError, "ERROR! This is meant to be a singleton!"
      end

      Webview::DisplayService.instance = self

      super()
      log_init("Webview::DisplayService")

      @display_drawable_for = {}
    end

    # Create a Webview display drawable for a specific Shoes drawable, and pair it with
    # the linkable ID for this Shoes drawable.
    #
    # @param drawable_class_name [String] The class name of the Shoes drawable, e.g. Shoes::Button
    # @param drawable_id [String] the linkable ID for drawable events
    # @param properties [Hash] a JSON-serialisable Hash with the drawable's Shoes styles
    # @param is_widget [Boolean] whether the class is a user-defined Shoes::Widget subclass
    # @return [Webview::Drawable] the newly-created Webview drawable
    def create_display_drawable_for(drawable_class_name, drawable_id, properties, is_widget:)
      existing = query_display_drawable_for(drawable_id, nil_ok: true)
      if existing
        @log.warn("There is already a display drawable for #{drawable_id.inspect}! Returning #{existing.class.name}.")
        return existing
      end

      if drawable_class_name == "App"
        unless @doc_root
          raise Scarpe::MissingDocRootError, "Webview::DocumentRoot is supposed to be created before Webview::App!"
        end

        display_app = Scarpe::Webview::App.new(properties)
        display_app.document_root = @doc_root
        @control_interface = display_app.control_interface
        @control_interface.doc_root = @doc_root
        @app = @control_interface.app
        @wrangler = @control_interface.wrangler

        set_drawable_pairing(drawable_id, display_app)

        return display_app
      end

      # Create a corresponding display drawable

      if is_widget
        display_class = Scarpe::Webview::Flow
      else
        display_class = Scarpe::Webview::Drawable.display_class_for(drawable_class_name)
        unless display_class < Scarpe::Webview::Drawable
          raise Scarpe::BadDisplayClassType, "Wrong display class type #{display_class.inspect} for class name #{drawable_class_name.inspect}!"
        end
      end
      display_drawable = display_class.new(properties)
      set_drawable_pairing(drawable_id, display_drawable)

      if drawable_class_name == "DocumentRoot"
        # DocumentRoot is created before App. Mostly doc_root is just like any other drawable,
        # but we'll want a reference to it when we create App.
        @doc_root = display_drawable
      end

      display_drawable
    end

    # Destroy the display service and the app. Quit the process (eventually.)
    #
    # @return [void]
    def destroy
      @app.destroy
      Webview::DisplayService.instance = nil
    end
  end
end
