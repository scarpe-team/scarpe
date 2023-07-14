# frozen_string_literal: true

module Shoes
  class InvalidAttributeValueError < Shoes::Error; end

  class Arc < Shoes::Widget
    display_properties :left, :top, :width, :height, :angle1, :angle2

    def initialize(*args)
      @left, @top, @width, @height, @angle1, @angle2 = args

      @left = convert_to_integer(@left, "left")
      @top = convert_to_integer(@top, "top")
      @width = convert_to_integer(@width, "width")
      @height = convert_to_integer(@height, "height")
      @angle1 = convert_to_float(@angle1, "angle1")
      @angle2 = convert_to_float(@angle2, "angle2")

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

    def convert_to_float(value, attribute_name)
      begin
        value = Float(value)
        raise InvalidAttributeValueError, "Negative number '#{value}' not allowed for attribute '#{attribute_name}'" if value < 0

        value
      rescue ArgumentError
        error_message = "Invalid value '#{value}' provided for attribute '#{attribute_name}'. The value should be a number."
        raise InvalidAttributeValueError, error_message
      end
    end
  end
end
