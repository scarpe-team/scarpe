# frozen_string_literal: true

# Scarpe::TextWidget

class Scarpe
  class TextWidget < Scarpe::Widget
    class << self
      # rubocop:disable Lint/MissingSuper
      def inherited(subclass)
        Scarpe::Widget.widget_classes ||= []
        Scarpe::Widget.widget_classes << subclass
      end
      # rubocop:enable Lint/MissingSuper
    end
  end

  class << self
    def default_text_widget_with(element)
      class_name = element.capitalize

      widget_class = Class.new(Scarpe::TextWidget) do
        display_property :content

        def initialize(content)
          @content = content

          super

          create_display_widget
        end
      end
      Scarpe.const_set class_name, widget_class
      widget_class.class_eval do
        display_property :content
      end
    end
  end
end

Scarpe.default_text_widget_with(:code)
Scarpe.default_text_widget_with(:em)
Scarpe.default_text_widget_with(:strong)
