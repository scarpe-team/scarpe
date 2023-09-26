# frozen_string_literal: true

module Shoes
  class EditBox < Shoes::Widget
    display_properties :text, :height, :width

    def initialize(text = "", height: nil, width: nil, &block)
      super
      @text = text
      @callback = block

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
