# frozen_string_literal: true

class Shoes
  class Rect < Shoes::Drawable
    shoes_styles :draw_context, :curve, :stroke, :fill
    shoes_events # No Rect-specific events

    init_args :left, :top, :width, :height
    opt_init_args :curve
    def initialize(*args, **kwargs)
      super

      @draw_context = @app.current_draw_context

      create_display_drawable
    end
  end
end
