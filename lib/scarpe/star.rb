# frozen_string_literal: true

class Scarpe
  class Star < Scarpe::Widget
    display_properties :left, :top, :points, :outer, :inner

    def initialize(left, top, points = 10, outer = 100.0, inner = 50.0)
      @left = left
      @top = top
      @points = points
      @outer = outer
      @inner = inner

      super
      create_display_widget
    end
  end
end
