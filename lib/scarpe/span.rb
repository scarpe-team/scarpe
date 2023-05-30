# frozen_string_literal: true

class Scarpe
  class Span < Scarpe::Widget
    display_properties :text, :stroke, :size, :font, :html_attributes

    def initialize(text, stroke: nil, size: :span, font: nil, **html_attributes)
      @text = text
      @stroke = stroke
      @size = size
      @font = font
      @html_attributes = html_attributes

      super

      create_display_widget
    end

    def replace(text)
      @text = text

      # This should signal the display widget to change
      self.text = @text
    end
  end
end
