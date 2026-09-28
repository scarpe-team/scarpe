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

    # Moves the whole line, so its far end keeps its place relative to the start: Shoes 3
    # draws a line across its place box (s3t_shape.c:127-132) and `move` shifts the box.
    #
    # @return [self]
    def move(left, top)
      return super unless [left, top, @left, @top, @x2, @y2].all?(Numeric)

      style(left:, top:, x2: @x2 + (left - @left), y2: @y2 + (top - @top))
      self
    end
  end
end
