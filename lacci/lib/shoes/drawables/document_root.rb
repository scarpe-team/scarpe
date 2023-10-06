# frozen_string_literal: true

module Shoes
  class DocumentRoot < Shoes::Flow
    def initialize
      @height = "100%"
      @width = @margin = @padding = nil
      @options = {}

      super

      create_display_drawable
    end

    # The default inspect string can be absolutely huge in console output, and it's frequently printed.
    def inspect
      "<Shoes::DocumentRoot>"
    end
  end
end
