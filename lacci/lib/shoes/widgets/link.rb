# frozen_string_literal: true

module Shoes
  class Link < Shoes::TextWidget
    display_properties :text, :click, :has_block

    def initialize(text, click: nil, &block)
      super

      @text = text
      @block = block
      # We can't send a block to the display widget, but we can send a boolean
      @has_block = !block.nil?

      # The click property should be changed before it gets sent to the display widget
      @click ||= "#"

      bind_self_event("click") do
        @block&.call
      end

      create_display_widget
    end
  end

  # In Shoes, the LinkHover pseudo-class is used to set default styles for links when
  # hovered over. The functionality isn't present in Lacci yet.
  class LinkHover < Link
    def initialize
      raise "This class should never be instantiated! Use link, not link_hover!"
    end
  end
end
