# frozen_string_literal: true

class Scarpe
  class DocumentRoot < Scarpe::Flow
    def initialize
      @height = "100%"
      @width = @margin = @padding = nil
      @options = {}

      super

      create_display_widget
    end

    # The default inspect string can be absolutely huge in console output, and it's frequently printed.
    def inspect
      "<Scarpe::DocumentRoot>"
    end
  end
end
