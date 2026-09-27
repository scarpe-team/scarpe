# frozen_string_literal: true

class Shoes
  class Line < Shoes::Drawable
    include Shoes::Art

    uses_draw_context
    shoes_styles :left, :top, :x2, :y2, :draw_context
    shoes_styles :stroke, :fill, :strokewidth # every shape's own pens (manual 1202-1210, 1453-1468, ledger D8)
    shoes_events # No Line-specific events yet

    init_args :left, :top, :x2, :y2
    def initialize(*args, **kwargs)
      super

      @draw_context = @app.current_draw_context

      create_display_drawable
    end
  end
end
