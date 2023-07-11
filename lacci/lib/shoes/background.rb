# frozen_string_literal: true

module Shoes
  module Background
    def self.included(includer)
      includer.display_property(:background_color)
    end

    # NOTE: this needs to be passed through in order for the styling to work
    def background(color, options = {})
      self.background_color = color
    end
  end
end
