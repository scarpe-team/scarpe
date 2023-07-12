# frozen_string_literal: true

module Shoes
  class Line < Shoes::Widget
    display_properties :left, :top, :x2, :y2, :draw_context

    def initialize(left, top, x2, y2)
      @left = left
      @top = top
      @x2 = x2
      @y2 = y2
      @draw_context = Shoes::App.instance.current_draw_context

      super
      create_display_widget
    end
  end
end
