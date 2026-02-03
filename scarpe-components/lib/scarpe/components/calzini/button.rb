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
        button_content(props, h)
      end
    end
  end

  private

  # Render button content with optional icon
  def button_content(props, h)
    icon = props["icon"]
    text = props["text"]
    icon_pos = (props["icon_pos"] || :left).to_sym

    return text unless icon

    # Wrap content in a flex container for proper icon/text alignment
    h.span(style: button_content_style(icon_pos)) do
      case icon_pos
      when :left
        h.img(src: icon, style: "max-height: 1.2em; margin-right: 4px; vertical-align: middle;")
        text
      when :right
        text.to_s + h.img(src: icon, style: "max-height: 1.2em; margin-left: 4px; vertical-align: middle;").to_s
      when :top
        h.span(style: "display: block; margin-bottom: 2px;") { h.img(src: icon, style: "max-height: 1.5em;") }
        text
      when :bottom
        text.to_s + h.span(style: "display: block; margin-top: 2px;") { h.img(src: icon, style: "max-height: 1.5em;") }.to_s
      else
        h.img(src: icon, style: "max-height: 1.2em; margin-right: 4px; vertical-align: middle;")
        text
      end
    end
  end

  def button_content_style(icon_pos)
    case icon_pos
    when :top, :bottom
      "display: inline-flex; flex-direction: column; align-items: center;"
    else
      "display: inline-flex; align-items: center;"
    end
  end

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
