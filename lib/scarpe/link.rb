# frozen_string_literal: true

class Scarpe
  class Link < Shoes::TextWidget
    display_properties :text, :click, :has_block

    def initialize(text, click: nil, &block)
      @text = text
      @block = block
      # We can't send a block to the display widget, but we can send a boolean
      @has_block = !block.nil?

      super

      # The click property should be changed before it gets sent to the display widget
      @click ||= "#"

      bind_self_event("click") do
        @block&.call
      end

      create_display_widget
    end
  end
end
