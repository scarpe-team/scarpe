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

      def default_text_widget_with(element)
        define_method(:initialize) do |content|
          @content = content
          super(content)
        end

        define_method(:element) do
          HTML.render do |h|
            h.send(element) { @content.to_s }
          end
        end
      end
    end
  end
end
