# frozen_string_literal: true

class Shoes
  class Arrow < Shoes::Drawable
    shoes_style :draw_context
    shoes_events # No Arrow-specific events yet

    [:left, :top, :width].each do |prop|
      shoes_style(prop) { |val| val.is_a?(Hash) ? val : convert_to_integer(val, prop) }
    end

    def initialize(*args)
      @draw_context = Shoes::App.instance.current_draw_context

      super

      if args.length == 1 && args[0].is_a?(Hash)
        options = args[0]
        self.left = options[:left]
        self.top = options[:top]
        self.width = options[:width]
      else
        self.left, self.top, self.width = args
      end

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
  end
end
