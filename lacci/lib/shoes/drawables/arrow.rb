# frozen_string_literal: true

module Shoes
  class Arrow < Shoes::Drawable
    shoes_style :draw_context

    [:left, :top, :width].each do |prop|
      shoes_style(prop) { |val| convert_to_integer(val, prop) }
    end

    def initialize(*args)
      @draw_context = Shoes::App.instance.current_draw_context

      super
      self.left, self.top, self.width = args

      create_display_drawable
    end

    def self.convert_to_integer(value, attribute_name)
      begin
        value = Integer(value)
        raise InvalidAttributeValueError, "Negative number '#{value}' not allowed for attribute '#{attribute_name}'" if value < 0

        value
      rescue ArgumentError
        error_message = "Invalid value '#{value}' provided for attribute '#{attribute_name}'. The value should be a number."
        raise InvalidAttributeValueError, error_message
      end
    end

    def self.convert_to_float(value, attribute_name)
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
