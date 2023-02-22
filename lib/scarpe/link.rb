# frozen_string_literal: true

class Scarpe
  class Link < Scarpe::TextWidget
    def initialize(text, click: nil, &block)
      @text = text
      @click = click || "#"
      @block = block

      super

      bind_self_event("click") do
        @block&.call
      end

      display_widget_properties(text, !block.nil?, click:)
    end
  end

  class WebviewLink < WebviewWidget
    def initialize(text, has_block, click:, shoes_linkable_id:)
      @text = text
      @has_block = has_block
      @click = click

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
