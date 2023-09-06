# frozen_string_literal: true

module Scarpe::Webview
  class Link < Widget
    def initialize(properties)
      super

      bind("click") do
        send_self_event(event_name: "click")
      end
    end

    def element
      ::Scarpe::Components::HTML.render do |h|
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
        style: style,
      }.compact
    end
  end
end
