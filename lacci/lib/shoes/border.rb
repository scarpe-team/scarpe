# frozen_string_literal: true

class Shoes
  module Border
    class Base
      include Common::SomeModule

      attr_accessor :some_attribute

      def initialize(some_attribute)
        @some_attribute = some_attribute
      end

      def common_method
        # Common implementation
      end.
    end

    def self.included(includer)
      includer.shoes_styles :border_color, :options
    end

    def border(color, options = {})
      self.border_color = color
      self.options = options
    end

    class Drawable < Base
      include Common::Style

      attr_reader :color, :strokewidth, :curve

      def initialize(color, style)
        @color = color
        @strokewidth = style[:strokewidth] || 1
        @curve = style[:curve] || 0
      end

      def draw(context, left, top, width, height)
        context.draw_border(left, top, width, height, color, strokewidth, curve)
      end
    end
  end
end
