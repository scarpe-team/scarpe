# frozen_string_literal: true

class Shoes
  class Star < Shoes::Drawable
    shoes_styles :left, :top, :draw_context

    shoes_style(:points) { |val| convert_to_integer(val, "points") }
    shoes_style(:outer) { |val| convert_to_float(val, "outer") }
    shoes_style(:inner) { |val| convert_to_float(val, "inner") }

    shoes_events() # No Star-specific events yet

    def initialize(left, top, points = 10, outer = 100, inner = 50)
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

    def self.convert_to_float(value, attribute_name)
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
