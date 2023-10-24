# frozen_string_literal: true

module Shoes
  class Span < Shoes::Drawable
    shoes_styles :text, :stroke, :size, :font, :html_attributes
    shoes_events() # No Span-specific events yet

    def initialize(text, stroke: nil, size: :span, font: nil, **html_attributes)
      super

      @text = text
      @stroke = stroke
      @size = size
      @font = font
      @html_attributes = html_attributes

      create_display_drawable
    end

    def replace(text)
      @text = text

      # This should signal the display drawable to change
      self.text = @text
    end
  end
end
