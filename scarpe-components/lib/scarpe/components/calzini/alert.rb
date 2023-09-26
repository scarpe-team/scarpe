# frozen_string_literal: true

module Scarpe::Components::Calzini
  def alert_element(props)
    onclick = handler_js_code("click")

    HTML.render do |h|
      h.div(id: html_id, style: alert_overlay_style(props)) do
        h.div(style: alert_modal_style) do
          h.div(style: {}) { props["text"] }
          h.button(style: {}, onclick: onclick) { "OK" }
        end
      end
    end
  end

  private

  # If the whole widget is hidden, the parent style adds display:none
  def alert_overlay_style(props)
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
    }.merge(widget_style(props))
  end

  def alert_modal_style
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
end
