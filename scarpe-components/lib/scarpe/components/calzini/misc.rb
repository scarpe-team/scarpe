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
      h.textarea(id: html_id, oninput: oninput,onmouseover: handler_js_code("hover"), style: edit_box_style(props),title: props["tooltip"]) { props["text"] }
    end
  end

  def edit_line_element(props)
    oninput = handler_js_code("change", "this.value")

    HTML.render do |h|
      h.input(
        id: html_id,
        type: props["secret"] ? :password : :text,
        oninput: oninput,
        onmouseover: handler_js_code("hover"),
        value: props["text"],
        style: edit_line_style(props),
        title: props["tooltip"]
      )
    end
  end

  def image_element(props)
    style = drawable_style(props)

    # Apply rotation and transform origin if set
    if props["rotate_angle"]
      style[:transform] = "rotate(#{props["rotate_angle"]}deg)"
    end
    if props["transform_origin"]
      style[:"transform-origin"] = props["transform_origin"]
    end

    # Add cursor pointer style if image has click handler
    style[:cursor] = "pointer" if props["click"]

    HTML.render do |h|
      h.img(
        id: html_id,
        src: props["url"],
        style: style,
        onclick: handler_js_code("click"),
        onmouseover: handler_js_code("hover"),
        onmouseout: handler_js_code("leave")
      )
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
      font: props["font"]? parse_font(props) : nil
    }.compact)
  end

  def edit_line_style(props)
    styles = drawable_style(props)

    styles[:font] = props["font"]? parse_font(props) : nil
    styles[:width] = dimensions_length(props["width"]) if props["width"]
    styles[:color] =  rgb_to_hex(props["stroke"])

    styles
  end

  def list_box_style(props)
    styles = drawable_style(props)

    styles[:font] = props["font"] ? parse_font(props) : nil
    styles[:height] = dimensions_length(props["height"]) if props["height"]
    styles[:width] = dimensions_length(props["width"]) if props["width"]
    styles[:color] = rgb_to_hex(props["stroke"]) if props["stroke"]

    styles
  end
end
