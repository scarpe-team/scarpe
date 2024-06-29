# frozen_string_literal: true

class Shoes
  class Line < Shoes::Drawable
    shoes_styles :left, :top, :x2, :y2, :draw_context
    shoes_events # No Line-specific events yet

    init_args :left, :top, :x2, :y2
    def initialize(*args, **kwargs)
      super

      @draw_context = @app.current_draw_context

      create_display_drawable
    end
  end
end
