# frozen_string_literal: true

class Scarpe
  class WebviewAlert < WebviewWidget
    def initialize(properties)
      super

      bind("click") do
        send_self_event(event_name: "click")
      end
    end

    def element
      onclick = handler_js_code("click")

      HTML.render do |h|
        h.div(id: html_id, style: overlay_style) do
          h.div(style: modal_style) do
            h.div(style: text_style) { @text }
            h.button(style: button_style, onclick: onclick) { "OK" }
          end
        end
      end
    end

    private

    def overlay_style
      {
        position: "fixed",
        top: "0",
        left: "0",
        width: "100%",
        height: "100%",
        overflow: "auto",
        "z-index": "1",
        background: "rgba(0,0,0,0.4)",
        display: "flex",
        "align-items": "center",
        "justify-content": "center",
      }
    end

    def modal_style
      {
        "min-width": "200px",
        "min-height": "50px",
        padding: "10px",
        display: "flex",
        background: "#fefefe",
        "flex-direction": "column",
        "justify-content": "space-between",
        "border-radius": "9px",
      }
    end

    def text_style
      {}
    end

    def button_style
      {}
    end
  end
end
