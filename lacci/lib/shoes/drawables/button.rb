# frozen_string_literal: true

module Shoes
  class Button < Shoes::Drawable
    include Shoes::Log
    shoes_styles :text, :width, :height, :top, :left, :color, :padding_top, :padding_bottom, :text_color, :size, :font_size,:tooltip
    shoes_events :click, :hover

    def initialize(text, width: nil, height: nil, top: nil, left: nil, color: nil, padding_top: nil, padding_bottom: nil, size: 12, text_color: nil,
      font_size: nil,tooltip: nil, &block)

      log_init("Button")

      # Properties passed as positional args, not keywords, don't get auto-set
      @text = text
      @block = block

      super

      # Bind to a handler named "click"
      bind_self_event("click") do
        @log.debug("Button clicked, calling handler") if @block
        @block&.call
      end

      bind_self_event("hover") do
        @hover&.call
      end

      create_display_drawable
    end

    # Set the click handler
    def click(&block)
      @block = block
    end

    def hover(&block)
      @hover = block
    end
  end
end
