# frozen_string_literal: true

class Scarpe
  class GlimmerLibUIDisplayService
    class << self
      attr_accessor :instance
    end

    attr_reader :app
    attr_reader :doc_root

    def initialize
      if GlimmerLibUIDisplayService.instance
        raise "ERROR! This is meant to be a singleton!"
      end

      GlimmerLibUIDisplayService.instance = self

      @display_widget_for = {}
    end

    def create_display_widget_for(widget_class_name, widget_id, properties)
      if widget_class_name == "Scarpe::App"
        unless @doc_root
          raise "GlimmerLibUIDocumentRoot is supposed to be created before GlimmerLibUIApp!"
        end

        display_app = Scarpe::GlimmerLibUIApp.new(properties)
        display_app.document_root = @doc_root
        @app = display_app

        set_widget_pairing(widget_id, display_app)

        return display_app
      end

      # Create a corresponding display widget
      display_class = Scarpe::GlimmerLibUIWidget.display_class_for(widget_class_name)
      display_widget = display_class.new(properties)
      set_widget_pairing(widget_id, display_widget)

      if widget_class_name == "Scarpe::DocumentRoot"
        @doc_root = display_widget
      end

      display_widget
    end

    def set_widget_pairing(id, display_widget)
      @display_widget_for[id] = display_widget
    end

    def query_display_widget_for(id, nil_ok: false)
      display_widget = @display_widget_for[id]
      unless display_widget || nil_ok
        raise "Could not find display widget for linkable ID #{id.inspect}!"
      end

      display_widget
    end
  end
end
