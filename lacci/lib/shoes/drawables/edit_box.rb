# frozen_string_literal: true

module Shoes
  class EditBox < Shoes::Drawable
    shoes_styles :text, :height, :width

    def initialize(text = "", height: nil, width: nil, &block)
      super
      @text = text
      @callback = block

      bind_self_event("change") do |new_text|
        self.text = new_text
        @callback&.call(self)
      end

      create_display_drawable
    end

    def change(&block)
      @callback = block
    end

    def append(new_text)
      self.text = self.text + new_text
    end
  end
end
