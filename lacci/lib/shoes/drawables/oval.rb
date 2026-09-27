# frozen_string_literal: true

class Shoes
  # Docs: https://github.com/scarpe-team/scarpe/blob/main/docs/static/manual.md#ovalleft-top-radius--shoesshape
  class Oval < Shoes::Drawable
    include Shoes::Art

    uses_draw_context
    shoes_styles :center, :draw_context, :stroke, :fill

    shoes_style(:left) { |val| convert_to_integer(val, "left") }
    shoes_style(:top) { |val| convert_to_integer(val, "top") }
    shoes_style(:radius) { |val| convert_to_integer(val, "radius") }
    shoes_style(:height) { |val| convert_to_integer(val, "height") }
    shoes_style(:width) { |val| convert_to_integer(val, "width") }
    shoes_style(:strokewidth) { |val| convert_to_integer(val, "strokewidth") }

    Shoes::Drawable.drawable_default_styles[Shoes::Oval][:fill] = "black"
    Shoes::Drawable.drawable_default_styles[Shoes::Oval][:stroke] = "black"

    # oval(left, top, diameter) and oval(left, top, width, height): the manual's
    # third argument, Shoes 3 and Shoes 4 all mean the full width here. Only the
    # radius: style is a true radius.
    init_args :left, :top
    opt_init_args :width, :height
    def initialize(*args, **options)
      super # Parse any positional or keyword args

      @draw_context = @app.current_draw_context

      # Placed by a near or a far edge on each axis, and sized by a size of its own
      # or by both edges of both axes (ledger C10).
      spans_across = !@left.nil? && !@right.nil?
      spans_down = !@top.nil? && !@bottom.nil?
      unless (@left || @right) && (@top || @bottom) && (@width || @height || @radius || (spans_across && spans_down))
        raise Shoes::Errors::InvalidAttributeValueError, "Oval requires left or right, top or bottom, and one of (width, height, radius) to be specified!"
      end

      # Calzini expects "radius" to mean the x-axis-aligned radius, not y-axis-aligned.
      # For an axis-aligned oval the two may be different.

      # If we have no width, but a radius, default the width to be the radius * 2
      @width ||= @radius * 2 if @radius

      # Default to a circle - set height from width or vice-versa, unless the oval
      # runs between both edges on that axis and takes its size from them.
      @width ||= @height unless spans_across
      @height ||= @width unless spans_down

      # If we don't have radius yet, set it from width
      @radius ||= @width / 2 if @width

      create_display_drawable
    end

  end
end
