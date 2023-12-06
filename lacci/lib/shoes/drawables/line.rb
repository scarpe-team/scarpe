# frozen_string_literal: true

class Shoes
  class Line < Shoes::Drawable
    shoes_styles :left, :top, :x2, :y2, :draw_context
    shoes_events # No Line-specific events yet

    init_args :left, :top, :x2, :y2
    def initialize(*args, **kwargs)
      @draw_context = Shoes::App.instance.current_draw_context

      super

      create_display_drawable
    end
  end
end
