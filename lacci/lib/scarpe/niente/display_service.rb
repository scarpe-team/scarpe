# frozen_string_literal: true

module Niente
  # This is a "null" DisplayService, doing as little as it
  # can get away with.
  class DisplayService < Shoes::DisplayService
    include Shoes::Log

    class << self
      attr_accessor :instance
    end

    def initialize
      if Niente::DisplayService.instance
        raise Scarpe::SingletonError, "ERROR! This is meant to be a singleton!"
      end

      Niente::DisplayService.instance = self

      log_init("Niente::DisplayService")
      super()
    end

    # Create a fake display drawable for a specific Shoes drawable, and pair it with
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
        @app = Niente::App.new(properties)
        set_drawable_pairing(drawable_id, @app)

        return @app
      end

      display_drawable = Niente::Drawable.new(properties)
      display_drawable.shoes_type = drawable_class_name
      set_drawable_pairing(drawable_id, display_drawable)

      return display_drawable
    end

    # Destroy the display service and the app. Quit the process (eventually.)
    #
    # @return [void]
    def destroy
      @app.destroy
      DisplayService.instance = nil
    end
  end
end

