# frozen_string_literal: true

# Scarpe::TextWidget

module Shoes
  class TextWidget < Shoes::Widget
    class << self
      # rubocop:disable Lint/MissingSuper
      def inherited(subclass)
        Shoes::Widget.widget_classes ||= []
        Shoes::Widget.widget_classes << subclass
      end
      # rubocop:enable Lint/MissingSuper
    end
  end

  class << self
    def default_text_widget_with(element)
      class_name = element.capitalize

      widget_class = Class.new(Shoes::TextWidget) do
        # Can we just change content to text to match the Shoes API?
        display_property :content

        def initialize(content)
          @content = content

          super

          create_display_widget
        end

        def text
          self.content
        end

        def text=(new_text)
          self.content = new_text
        end
      end
      Shoes.const_set class_name, widget_class
      widget_class.class_eval do
        display_property :content
      end
    end
  end
end

Shoes.default_text_widget_with(:code)
Shoes.default_text_widget_with(:em)
Shoes.default_text_widget_with(:strong)
