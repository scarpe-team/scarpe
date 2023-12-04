# frozen_string_literal: true

module Shoes
  # Docs: https://github.com/scarpe-team/scarpe/blob/main/docs/static/manual.md#ovalleft-top-radius--shoesshape
  class Oval < Shoes::Drawable
    shoes_styles :height, :center, :draw_context, :stroke

    shoes_style(:left) { |val| convert_to_integer(val, "left") }
    shoes_style(:top) { |val| convert_to_integer(val, "top") }
    shoes_style(:radius) { |val| convert_to_integer(val, "radius") }
    shoes_style(:height) { |val| convert_to_integer(val, "height") }
    shoes_style(:width) { |val| convert_to_integer(val, "width") }
    shoes_style(:strokewidth) { |val| convert_to_integer(val, "strokewidth") }

    def initialize(left = nil, top = nil, radius = nil, height = nil, **options)
      super
      self.left, self.top, self.radius, self.height =
        left || options[:left],
        top || options[:top],
        radius || options[:radius] || options[:width] / 2, # The radius positional arg change forces us to do this
        height || options[:height]

      @draw_context = Shoes::App.instance.current_draw_context

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
