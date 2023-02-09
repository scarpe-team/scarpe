# frozen_string_literal: true

class Scarpe
  class Link < Scarpe::TextWidget
    def initialize(text, click: nil, &block)
      @text = text
      @click = click || "#"
      @block = block

      bind("click") do
        @block&.call
      end
      super
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
        onclick: (handler_js_code("click") if @block),
      }.compact
    end
  end
end
