# frozen_string_literal: true

class Scarpe
  class EditBox < Scarpe::Widget
    display_properties :text, :height, :width

    def initialize(text = nil, height: nil, width: nil, &block)
      @text = text.nil? ? block&.call : text || ""

      super

      bind_self_event("change") do |new_text|
        self.text = new_text
        @callback&.call(new_text)
      end

      create_display_widget
    end

    def change(&block)
      @callback = block
    end
  end
end
