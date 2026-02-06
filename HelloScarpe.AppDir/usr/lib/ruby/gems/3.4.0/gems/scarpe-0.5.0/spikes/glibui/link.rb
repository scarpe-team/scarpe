# frozen_string_literal: true

class Scarpe
  class GlimmerLibUILink < GlimmerLibUIWidget
    def initialize(properties)
      super

      bind("click") do
        send_self_event(event_name: "click")
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
