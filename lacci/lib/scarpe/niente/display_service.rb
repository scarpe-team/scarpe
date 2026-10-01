# frozen_string_literal: true

module Niente
  # This is a "null" DisplayService, doing as little as it
  # can get away with.
  class DisplayService < Shoes::DisplayService
    include Shoes::Log

    class << self
      attr_accessor :instance
    end

    # What a headless display answers when nothing stubbed the dialog.
    HEADLESS_BUILTIN_ANSWERS = { "confirm" => false, "ask" => "" }.freeze
    # Niente keeps no clipboard; left unanswered, these reach the system's (Shoes::Clipboard).
    SYSTEM_BUILTINS = %w[clipboard clipboard=].freeze

    # Niente shows nothing, dialogs included. Answering every builtin keeps
    # Lacci from falling back to an osascript dialog in the middle of a test.
    def self.answer_builtins_headlessly
      Shoes::DisplayService.subscribe_to_event("builtin", nil) do |cmd_name, _args|
        next if SYSTEM_BUILTINS.include?(cmd_name)

        Shoes::DisplayService.set_builtin_response(HEADLESS_BUILTIN_ANSWERS[cmd_name])
      end
    end

    def initialize
      if Niente::DisplayService.instance
        raise Shoes::SingletonError, "ERROR! This is meant to be a singleton!"
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
    def create_display_drawable_for(drawable_class_name, drawable_id, properties, parent_id:, is_widget:)
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

      # Nil parent is okay for DocumentRoot and TextDrawables, so we have to specify it.
      parent = DisplayService.instance.query_display_drawable_for(parent_id, nil_ok: true)
      display_drawable.set_parent(parent, index: index_in_shoes_parent(drawable_id))

      return display_drawable
    end

    # The drawable is already in its Shoes parent's children when its display
    # drawable is created, so this is the position a remote display is sent.
    def index_in_shoes_parent(drawable_id)
      drawable = Shoes::Drawable.drawable_by_id(drawable_id, none_ok: true)
      drawable&.parent&.contents&.index(drawable)
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

