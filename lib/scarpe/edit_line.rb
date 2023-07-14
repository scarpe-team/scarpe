# frozen_string_literal: true

class Scarpe
  class EditLine < Shoes::Widget
    display_properties :text, :width

    def initialize(text = "", width: nil, &block)
      @block = block
      @text = text

      super

      bind_self_event("change") do |new_text|
        self.text = new_text
        @block&.call(new_text)
      end

      create_display_widget
    end

    def change(&block)
      @block = block
    end
  end
end
