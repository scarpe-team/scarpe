# frozen_string_literal: true

class Shoes
  class Border < Shoes::Drawable
    # Shoes style with verification or value mapping:
    # shoes_style(:left) { |val| convert_to_integer(val, "left") }

    shoes_styles :stroke, :strokewidth  # Write your shoes styles here

    shoes_style(:strokewidth) { |val| convert_to_integer(val, "strokewidth") }
    shoes_style(:curve) { |val| convert_to_integer(val, "curve") }

    Shoes::Drawable.drawable_default_styles[Shoes::Border][:stroke] = :black
    Shoes::Drawable.drawable_default_styles[Shoes::Border][:strokewidth] = 1
    Shoes::Drawable.drawable_default_styles[Shoes::Border][:curve] = 0
    
    opt_init_args :stroke, :strokewidth, :curve
    def initialize(*args, **kwargs)
      super
      @draw_context = Shoes::App.instance.current_draw_context

      create_display_drawable
    end

    private

  end
end
