# frozen_string_literal: true

class Scarpe
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
