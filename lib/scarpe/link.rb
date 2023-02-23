# frozen_string_literal: true

class Scarpe
  class Link < Scarpe::TextWidget
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

  class WebviewLink < WebviewWidget
    def initialize(properties)
      super

      bind("click") do
        send_display_event(event_name: "click", target: shoes_linkable_id)
      end
    end

    def element
      HTML.render do |h|
        h.a(**attributes) do
          @text
        end
      end
    end

    def attributes
      {
        id: html_id,
        href: @click,
        onclick: (handler_js_code("click") if @has_block),
      }.compact
    end
  end
end
