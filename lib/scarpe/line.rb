# frozen_string_literal: true

class Scarpe
  class Line < Scarpe::Widget
    display_properties :left, :top, :x2, :y2

    def initialize(left, top, x2, y2)
      @left = convert_to_integer(left, "left")
      @top = convert_to_integer(top, "top")
      @x2 = convert_to_integer(x2, "x2")
      @y2 = convert_to_integer(y2, "y2")

      super()
      create_display_widget
    end

    private

    def convert_to_integer(value, attribute_name)
      begin
        value = Integer(value)
        raise InvalidAttributeValueError, "Negative number '#{value}' not allowed for attribute '#{attribute_name}'" if value < 0

        value
      rescue ArgumentError
        error_message = "Invalid value '#{value}' provided for attribute '#{attribute_name}'. The value should be a number."
        raise InvalidAttributeValueError, error_message
      end
    end
  end
end
