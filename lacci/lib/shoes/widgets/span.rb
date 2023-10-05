# frozen_string_literal: true

module Shoes
  class Span < Shoes::Widget
    display_properties :text, :stroke, :size, :font, :html_attributes

    def initialize(text, stroke: nil, size: :span, font: nil, **html_attributes)
      super

      @text = text
      @stroke = stroke
      @size = size
      @font = font
      @html_attributes = html_attributes

      create_display_widget
    end

    def replace(text)
      @text = text

      # This should signal the display widget to change
      self.text = @text
    end
  end
end
