# frozen_string_literal: true

# TODO: REMOVE THIS
require "scarpe/wv/shape_helper"

module Shoes
  class Line < Shoes::Widget
    include ShapeHelper

    display_properties :left, :top, :x2, :y2, :color

    def initialize(left, top, x2, y2)
      validate_coordinates(x2, y2)
      @left = left
      @top = top
      @x2 = x2
      @y2 = y2
      @color = color_for_fill

      # validate_coordinates(x2, y2)

      super()
      create_display_widget
    end
  end
end
