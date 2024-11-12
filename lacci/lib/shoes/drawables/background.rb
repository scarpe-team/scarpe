# class_template.erb
# frozen_string_literal: true

class Shoes
  class Background < Shoes::Drawable

    shoes_styles :fill

    shoes_style(:curve) { |val| convert_to_integer(val, "curve") }

    Shoes::Drawable.drawable_default_styles[Shoes::Border][:curve] = 0

    init_args :fill
    opt_init_args :curve
    def initialize(*args, **kwargs)
      
      super
      @draw_context = Shoes::App.instance.current_draw_context

      create_display_drawable
    end

  end
end
