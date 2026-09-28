# frozen_string_literal: true

class Shoes
  class Rect < Shoes::Drawable
    include Shoes::Art

    uses_draw_context
    shoes_styles :draw_context, :curve, :stroke, :fill
    shoes_styles :strokewidth, :center # every shape's (ledger D8), rect's by the manual (E2)
    shoes_events # No Rect-specific events

    init_args :left, :top, :width, :height
    opt_init_args :curve
    def initialize(*args, **kwargs)
      # In Shoes, rect can be called with fewer positional args:
      # rect(left, top, width) — height defaults to width (square)
      # rect(left, top, width, height) — full spec
      # rect(side) — square at origin
      # Also supports keyword args without positional: rect(left: 10, top: 10, width: 40)
      # Or even rect(width: 40) — left/top default to 0, unless right/bottom place it (C10)
      if args.empty?
        kwargs[:left] ||= 0 unless kwargs.key?(:right)
        kwargs[:top] ||= 0 unless kwargs.key?(:bottom)
        kwargs[:height] ||= kwargs[:width] if kwargs[:width]
      elsif args.length == 3
        # rect(left, top, width) — height defaults to width
        args << args[2]
      elsif args.length == 2
        # rect(width, height) — at origin
        args = [0, 0, args[0], args[1]]
      elsif args.length == 1
        # rect(side) — square at origin
        args = [0, 0, args[0], args[0]]
      end

      super(*args, **kwargs)

      @draw_context = @app.current_draw_context

      create_display_drawable
    end
  end
end
