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
end
