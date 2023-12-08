# frozen_string_literal: true

module Scarpe::Components::Calzini
  def check_element(props)
    HTML.render do |h|
      h.input type: :checkbox,
        id: html_id,
        onclick: handler_js_code("click"),
        value: props["text"],
        checked: props["checked"],
        style: drawable_style(props)
    end
  end

  def edit_box_element(props)
    oninput = handler_js_code("change", "this.value")

    HTML.render do |h|
      h.textarea(id: html_id, oninput: oninput, style: edit_box_style(props)) { props["text"] }
    end
  end

  def edit_line_element(props)
    oninput = handler_js_code("change", "this.value")

    HTML.render do |h|
      h.input(id: html_id, oninput: oninput, value: props["text"], style: edit_line_style(props))
    end
  end

  def image_element(props)
    style = image_style(props)

    if props["click"]
      HTML.render do |h|
        h.a(id: html_id, href: props["click"]) { h.img(id: html_id, src: props["url"], style:) }
      end
    else
      HTML.render do |h|
        h.img(id: html_id, src: props["url"], style:)
      end
    end
  end

  def list_box_element(props)
    onchange = handler_js_code("change", "this.options[this.selectedIndex].value")

    # Is this useful at all? Is it overridden below completely?
    option_attrs = { value: nil, selected: false }

    HTML.render do |h|
      h.select(id: html_id, onchange:, style: list_box_style(props)) do
        (props["items"] || []).each do |item|
          option_attrs = {
            value: item,
          }
          if item == props["choose"]
            option_attrs[:selected] = "true"
          end
          h.option(**option_attrs) do
            item
          end
        end
      end
    end
  end

  def radio_element(props)
    # This is wrong - need to default to the parent slot -- maybe its linkable ID?
    group_name = props["group"] || "no_group"

    HTML.render do |h|
      h.input(
        type: :radio,
        id: html_id,
        onclick: handler_js_code("click"),
        name: group_name,
        value: props["text"],
        checked: props["checked"],
        style: drawable_style(props),
      )
    end
  end

  def video_element(props)
    HTML.render do |h|
      h.video(id: html_id, style: drawable_style(props), controls: true) do
        h.source(src: @url, type: props["format"])
      end
    end
  end

  def progress_element(props)
    HTML.render do |h|
      h.progress(
        id: html_id,
        style: drawable_style(props),
        role: "progressbar",
        "aria-valuenow": props["fraction"],
        "aria-valuemin": 0.0,
        "aria-valuemax": 1.0,
        max: 1,
        value: props["fraction"],
      )
    end
  end

  private

  def edit_box_style(props)
    drawable_style(props).merge({
      height: dimensions_length(props["height"]),
      width: dimensions_length(props["width"]),
    }.compact)
  end

  def edit_line_style(props)
    styles = drawable_style(props)

    styles[:width] = dimensions_length(props["width"]) if props["width"]

    styles
  end

  def image_style(props)
    styles = drawable_style(props)

    styles[:width] = dimensions_length(props["width"]) if props["width"]
    styles[:height] = dimensions_length(props["height"]) if props["height"]

    styles[:top] = dimensions_length(props["top"]) if props["top"]
    styles[:left] = dimensions_length(props["left"]) if props["left"]
    styles[:position] = "absolute" if props["top"] || props["left"]

    styles
  end

  def list_box_style(props)
    styles = drawable_style(props)

    styles[:height] = dimensions_length(props["height"]) if props["height"]
    styles[:width] = dimensions_length(props["width"]) if props["width"]

    styles
  end

  def codes_element(props)
    HTML.render do |h|
      h.pre(id: html_id, style: code_pre_style(props)) do
        h.code do
          props["text"]
        end
      end
    end
  end

  def code_pre_style(props)
    styles = drawable_style(props)
    styles["background-color"] = "#2E2E2E"
    styles["color"] = "#FFFFFF"
    styles["font-family"] = "'Courier New', monospace"
    styles["max-width"] = "80vw"
    styles["max-height"] = "60vh"
    styles["overflow"] = "auto"
    styles["padding"] = "20px"
    styles["border-radius"] = "10px"
    styles["box-shadow"] = "0 0 15px rgba(0, 0, 0, 0.4)"
    styles["border"] = "2px solid #444"
    styles["line-height"] = "1.4"

    styles
  end

  def code_code_style(props)
    styles = drawable_style(props)
    styles["background-color"] = "#2E2E2E"

    styles
  end
end
