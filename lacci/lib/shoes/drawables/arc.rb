# frozen_string_literal: true

class Shoes
  class Arc < Shoes::Drawable
    shoes_style :draw_context
    shoes_events # No Arc-specific events yet

    [:left, :top, :width, :height].each do |prop|
      shoes_style(prop) { |val| convert_to_integer(val, prop) }
    end

    [:angle1, :angle2].each do |prop|
      shoes_style(prop) { |val| convert_to_float(val, prop) }
    end

    init_args :left, :top, :width, :height, :angle1, :angle2
    def initialize(*args, **kwargs)
      super

      @draw_context = @app.current_draw_context

      create_display_drawable
    end


  end
end
