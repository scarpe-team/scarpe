# frozen_string_literal: true

module Shoes
  class EditBox < Shoes::Widget
    display_properties :text, :height, :width, :margin_bottom

    def initialize(text = "", height: nil, width: nil, margin_bottom: nil, &block)
      @text = text
      @callback = block

      super

      bind_self_event("change") do |new_text|
        self.text = new_text
        @callback&.call(self)
      end

      create_display_widget
    end

    def change(&block)
      @callback = block
    end

    def append(new_text)
      self.text = self.text + new_text
    end
  end
end
