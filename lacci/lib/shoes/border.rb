# frozen_string_literal: true

module Shoes
  module Border
    def self.included(includer)
      includer.shoes_styles :border_color, :options
    end

    # Considering a signature like this:
    # border "#00D0FF", :strokewidth => 3, :curve => 12
    def border(color, options = {})
      self.border_color = color
      self.options = options
    end
  end
end
