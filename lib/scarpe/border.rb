# frozen_string_literal: true

class Scarpe
  module Border
    def self.included(includer)
      includer.display_properties :border_color, :options
    end

    # Considering a signature like this:
    # border "#00D0FF", :strokewidth => 3, :curve => 12
    def border(color, options = {})
      @border_color = color
      @options = options
    end
  end
end
