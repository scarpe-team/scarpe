# frozen_string_literal: true

module Shoes
  class Line < Shoes::Widget
    display_properties :left, :top, :x2, :y2, :draw_context

    def initialize(left, top, x2, y2)
      super

      @left = left
      @top = top
      @x2 = x2
      @y2 = y2
      @draw_context = Shoes::App.instance.current_draw_context

      create_display_widget
    end
  end
end
