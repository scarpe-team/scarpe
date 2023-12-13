# frozen_string_literal: true

class Shoes
  # Docs: https://github.com/scarpe-team/scarpe/blob/main/docs/static/manual.md#ovalleft-top-radius--shoesshape
  class Oval < Shoes::Drawable
    shoes_styles :center, :draw_context, :stroke, :fill

    shoes_style(:left) { |val| convert_to_integer(val, "left") }
    shoes_style(:top) { |val| convert_to_integer(val, "top") }
    shoes_style(:radius) { |val| convert_to_integer(val, "radius") }
    shoes_style(:height) { |val| convert_to_integer(val, "height") }
    shoes_style(:width) { |val| convert_to_integer(val, "width") }
    shoes_style(:strokewidth) { |val| convert_to_integer(val, "strokewidth") }

    init_args :left, :top
    opt_init_args :radius, :height
    def initialize(*args, **options)
      @draw_context = Shoes::App.instance.current_draw_context

      super # Parse any positional or keyword args

      unless @left && @top && (@width || @height || @radius)
        raise Shoes::Errors::InvalidAttributeValueError, "Oval requires left, top and one of (width, height, radius) to be specified!"
      end

      # Calzini expects "radius" to mean the x-axis-aligned radius, not y-axis-aligned.
      # For an axis-aligned oval the two may be different.

      # If we have no width, but a radius, default the width to be the radius * 2
      @width ||= @radius * 2 if @radius

      # We now know we have width or height, but maybe not both.

      # Default to a circle - set height from width or vice-versa
      @width ||= @height
      @height ||= @width

      # If we don't have radius yet, set it from width
      @radius ||= @width / 2

      create_display_drawable
    end

  end
end
