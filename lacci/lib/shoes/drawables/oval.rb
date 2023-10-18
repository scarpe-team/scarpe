# frozen_string_literal: true

module Shoes
  class Oval < Shoes::Drawable
    shoes_styles :height, :center, :fill, :stroke, :strokewidth

    shoes_style(:left) { |val| convert_to_integer(val, "left") }
    shoes_style(:top) { |val| convert_to_integer(val, "top") }
    shoes_style(:radius) { |val| convert_to_integer(val, "width") }

    def initialize(left = nil, top = nil, radius = nil, height = nil, **options)
      super
      self.left, self.top, self.points, self.outer, self.inner = left, top, points, outer, inner

      @draw_context = Shoes::App.instance.current_draw_context

      create_display_drawable
    end

    private

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
