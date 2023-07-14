# frozen_string_literal: true

require_relative "wv/shape_helper"

class Scarpe
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
