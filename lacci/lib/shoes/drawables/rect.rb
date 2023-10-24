# frozen_string_literal: true

module Shoes
  class Rect < Shoes::Drawable
    shoes_styles :left, :top, :width, :height, :draw_context, :curve
    shoes_events() # No Rect-specific events yet

    def initialize(*args)
      @draw_context = Shoes::App.instance.current_draw_context

      super
      self.left, self.top, self.width, self.height, self.curve = args

      create_display_drawable
    end
  end
end
