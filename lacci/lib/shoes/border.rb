# frozen_string_literal: true

module Shoes
  # The `Border` module provides methods for defining border styles in a Shoes-based application.
  module Border
    # This class method is automatically invoked when the `Border` module is included in another class or module.
    # It sets up the styles for border color and options.
    #
    # @param includer [Class] The class or module that includes the `Border` module.
    def self.included(includer)
      includer.shoes_styles :border_color, :options
    end

    # Set the border style for an element.
    #
    # @param color [String] The color of the border.
    # @param options [Hash] (optional) A hash of options for customizing the border style.
    #
    # @see https://github.com/scarpe-team/scarpe/tree/main/docs/examples/border.rb
    def border(color, options = {})
      self.border_color = color
      self.options = options
    end
  end
end
