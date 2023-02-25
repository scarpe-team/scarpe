# frozen_string_literal: true

require "glimmer-dsl-libui"

class Scarpe
  # Scarpe::GlimmerLibUIApp must only be used from the main thread, due to GTK+ limitations.
  class GlimmerLibUIApp < GlimmerLibUIWidget
    include Glimmer

    attr_reader :debug
    attr_writer :shoes_linkable_id

    def initialize(properties)
      super

      bind_display_event(event_name: "run") do
        code = @document_root.display
        puts code
        # This is for if I want to confirm textual output. But not actually fire up the service.
        exit if ENV["NO_RUN"]
        eval code
      end
    end

    attr_writer :document_root
  end
end
