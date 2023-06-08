# frozen_string_literal: true

class Scarpe
  class InvalidAttributeValueError < StandardError; end

  class Oval < Scarpe::Widget
    display_properties :left, :top, :width, :height, :center, :fill, :stroke, :strokewidth

    def initialize(left = nil, top = nil, width = nil, height = nil, **options)
      @left = convert_to_integer(left || options.fetch(:left), "left")
      @top = convert_to_integer(top || options.fetch(:top), "top")
      @width = convert_to_float(width || options.fetch(:radius) * 2, "width")
      @height = if height.nil?
        @width
      else
        convert_to_float(height, "height")
      end
      @center = options.fetch(:center, false)
      @fill = options.fetch(:fill, nil)
      @stroke = options.fetch(:stroke, nil)
      @stroke_width = options.fetch(:strokewidth, 2)

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
