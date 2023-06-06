# frozen_string_literal: true

class Scarpe
  class InvalidAttributeValueError < StandardError; end

  class Star < Scarpe::Widget
    display_properties :left, :top, :points, :outer, :inner

    def initialize(left, top, points = 10, outer = 100, inner = 50)
      @left = convert_to_integer(left, "left")
      @top = convert_to_integer(top, "top")
      @points = convert_to_integer(points, "points", 10)
      @outer = convert_to_float(outer, "outer", 100.0)
      @inner = convert_to_float(inner, "inner", 50.0)

      super()
      create_display_widget
    end

    private

    def convert_to_integer(value, attribute_name, default = 0)
      begin
        value = Integer(value)
        raise InvalidAttributeValueError, "Negative num '#{value}' not allowed for attribute '#{attribute_name}'" if value < 0

        value
      rescue ArgumentError
        error_message = "Invalid value '#{value}' provided for attribute '#{attribute_name}'. The value should be a number."
        raise InvalidAttributeValueError, error_message
      end
    end

    def convert_to_float(value, attribute_name, default = 0.0)
      begin
        value = Float(value)
        raise InvalidAttributeValueError, "Negative num '#{value}' not allowed for attribute '#{attribute_name}'" if value < 0

        value
      rescue ArgumentError
        error_message = "Invalid value '#{value}' provided for attribute '#{attribute_name}'. The value should be a number."
        raise InvalidAttributeValueError, error_message
      end
    end
  end
end
