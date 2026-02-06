# frozen_string_literal: true

module Scarpe::Components::Calzini
  def button_element(props)
    HTML.render do |h|
      button_props = {
        id: html_id,
        onclick: handler_js_code("click"),
        onmouseover: handler_js_code("hover"),
        style: button_style(props),
        class: props["html_class"],
        title: props["tooltip"],
      }.compact
      h.button(**button_props) do
        props["text"]
      end
    end
  end

  private

  def button_style(props)
    styles = drawable_style(props)

    styles[:"background-color"] = props["color"] if props["color"]
    styles[:"padding-top"] = props["padding_top"] if props["padding_top"]
    styles[:"padding-bottom"] = props["padding_bottom"] if props["padding_bottom"]
    styles[:color] = props["text_color"] if props["text_color"]

    styles[:"font-size"] = props["font_size"] if props["font_size"]
    styles[:"font-size"] = dimensions_length(text_size(props["size"])) if props["size"]

    styles[:"font-family"] = props["font"] if props["font"]

    styles
  end
end
