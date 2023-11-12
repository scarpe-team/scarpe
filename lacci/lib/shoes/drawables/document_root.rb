# frozen_string_literal: true

class Shoes
  class DocumentRoot < Shoes::Flow
    shoes_events() # No DocumentRoot-specific events yet

    def initialize
      @height = "100%"
      @width = @margin = @padding = nil
      @options = {}

      super
    end

    # The default inspect string can be absolutely huge in console output, and it's frequently printed.
    def inspect
      "<Shoes::DocumentRoot>"
    end
  end
end
