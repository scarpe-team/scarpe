# frozen_string_literal: true

module Shoes
  class Arc < Shoes::Widget
    display_properties :left, :top, :width, :height, :angle1, :angle2, :draw_context

    [:left, :top, :width, :height].each do |prop|
      display_property(prop) { |val| convert_to_integer(val, prop) }
    end

    [:angle1, :angle2].each do |prop|
      display_property(prop) { |val| convert_to_float(val, prop) }
    end

    def initialize(*args)
      @draw_context = Shoes::App.instance.current_draw_context

      super
      self.left, self.top, self.width, self.height, self.angle1, self.angle2 = args

      create_display_widget
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
