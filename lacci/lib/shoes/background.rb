# frozen_string_literal: true

class Shoes
  # Mixin module that gives slots the background() method and background_color style.
  # Include this in slots (Stack, Flow, Widget) to enable background drawing.
  module HasBackground
    def self.included(includer)
      includer.shoes_style(:background_color)
    end

    # Create a Background drawable with the given color.
    # Returns the Background drawable so it can be styled:
    #   @back = background blue
    #   @back.style :height => 10
    #
    # In Shoes3, background() inside a slot creates a separate drawable
    # that can be independently styled, shown/hidden, and destroyed.
    #
    # @param color [String,Range,Array] the fill color (string, gradient Range, or RGBA array)
    # @param options [Hash] optional styles like :curve, :height, :width
    # @return [Shoes::Background] the created Background drawable
    def background(color, options = {})
      # Create the Background drawable with the fill color.
      # We need to set up the app context properly so the drawable
      # can access @app during initialization.
      instance = nil
      @app.with_slot(self) do
        Shoes::Drawable.with_current_app(self.app) do
          instance = Shoes::Background.new(fill: color, **options)
        end
      end
      instance
    end
  end
end
