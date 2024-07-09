# frozen_string_literal: true

class Shoes
  class Arrow < Shoes::Drawable
    shoes_style :draw_context
    shoes_events # No Arrow-specific events yet

    [:left, :top, :width].each do |prop|
      shoes_style(prop) { |val| val.is_a?(Hash) ? val : convert_to_integer(val, prop) }
    end

    init_args :left, :top, :width
    def initialize(*args, **kwargs)
      super

      @draw_context = @app.current_draw_context

      create_display_drawable
    end
  end
end
