# frozen_string_literal: true

class Shoes
  class Star < Shoes::Drawable
    shoes_styles :left, :top, :draw_context

    shoes_style(:points) { |val| convert_to_integer(val, "points") }
    shoes_style(:outer) { |val| convert_to_float(val, "outer") }
    shoes_style(:inner) { |val| convert_to_float(val, "inner") }

    Shoes::Drawable.drawable_default_styles[Shoes::Star][:points] = 10
    Shoes::Drawable.drawable_default_styles[Shoes::Star][:outer] = 100
    Shoes::Drawable.drawable_default_styles[Shoes::Star][:inner] = 50

    shoes_events # No Star-specific events

    init_args :left, :top
    opt_init_args :points, :outer, :inner
    def initialize(*args, **kwargs)
      super

      @draw_context = Shoes::App.instance.current_draw_context

      create_display_drawable
    end

  end
end
