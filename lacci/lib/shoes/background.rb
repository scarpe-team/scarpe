# frozen_string_literal: true

module Shoes
  # The `Background` module provides functionality for setting the background color
  module Background
    # @param includer [Class] The class including this module.
    def self.included(includer)
      includer.shoes_style(:background_color)
    end

    # Set the background color of the object to the specified color.
    #
    # @param color [String] The background color to set. This should be a valid color representation, such as a color name (e.g., "red") or a hex code (e.g., "#FF0000").
    # @param options [Hash] (optional) Additional options for setting the background.
    # @option options [Any] :option_name A description of an optional parameter.
    #
    # @return [void]
    #
    # @see https://github.com/scarpe-team/scarpe/tree/main/docs/examples/background.rb
    # NOTE: This method needs to be called in order for the styling to work properly.
    def background(color, options = {})
      self.background_color = color
    end
  end
end
