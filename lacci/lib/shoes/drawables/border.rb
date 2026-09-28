# frozen_string_literal: true

class Shoes
  class Border < Shoes::Drawable
    include Shoes::Pattern

    uses_draw_context
    shoes_style(:stroke) { |paint| Shoes::Pattern.paint(paint) } # another pattern strokes this one too
    shoes_style(:strokewidth) { |val| convert_to_integer(val, "strokewidth") }
    shoes_style(:curve) { |val| convert_to_integer(val, "curve") }

    Shoes::Drawable.drawable_default_styles[Shoes::Border][:stroke] = :black
    Shoes::Drawable.drawable_default_styles[Shoes::Border][:strokewidth] = 1
    Shoes::Drawable.drawable_default_styles[Shoes::Border][:curve] = 0
    
    opt_init_args :stroke, :strokewidth, :curve
    def initialize(*args, **kwargs)
      # A border's width is its own, 1 unless given: Shoes 3 strokes it with the border's
      # strokewidth alone (shoes_border_draw, s3t_pattern.c:219). The pen's strokewidth is
      # for shapes, and a hairline border drawn after thick art stays a hairline.
      kwargs[:strokewidth] = 1 unless args.size > 1 || kwargs.key?(:strokewidth)
      super
      @draw_context = @app.current_draw_context

      create_display_drawable
    end

    # @return [Object] the colour, gradient or image this border strokes with
    def paint
      @stroke
    end
  end
end
