# frozen_string_literal: true

class Shoes
  # Docs: https://github.com/scarpe-team/scarpe/blob/main/docs/static/manual.md#ovalleft-top-radius--shoesshape
  class Oval < Shoes::Drawable
    shoes_styles :center, :draw_context, :stroke

    shoes_style(:left) { |val| convert_to_integer(val, "left") }
    shoes_style(:top) { |val| convert_to_integer(val, "top") }
    shoes_style(:radius) { |val| convert_to_integer(val, "radius") }
    shoes_style(:height) { |val| convert_to_integer(val, "height") }
    shoes_style(:width) { |val| convert_to_integer(val, "width") }
    shoes_style(:strokewidth) { |val| convert_to_integer(val, "strokewidth") }

    init_args :left, :top, :radius, :height
    def initialize(*args, **options)
      @draw_context = Shoes::App.instance.current_draw_context

      super # Parse any positional or keyword args

      unless @left && @top && (@width || @height || @radius)
        raise Shoes::Errors::InvalidAttributeValueError, "Oval requires left, top and one of (width, height, radius) to be specified!"
      end

      # Calzini expects "radius" to mean the x-axis-aligned radius, not y-axis-aligned.
      # For an axis-aligned oval the two may be different.

      # If we have no width, but a radius, default the width to be the radius * 2
      @width ||= @radius * 2

      # If we have width or height, set the other (and optionally radius) from what we have.
      if @width || @height
        @width ||= @height
        @height ||= @width
        @radius ||= @width / 2
      else
        # No width or height, so it's all from radius
        @width = @height = @radius
      end

      create_display_drawable
    end

    def self.convert_to_integer(value, attribute_name)
      begin
        value = Integer(value)
        raise InvalidAttributeValueError, "Negative num '#{value}' not allowed for attribute '#{attribute_name}'" if value < 0

        value
      rescue ArgumentError
        error_message = "Invalid value '#{value}' provided for attribute '#{attribute_name}'. The value should be a number."
        raise InvalidAttributeValueError, error_message
      end
    end
  end
end
