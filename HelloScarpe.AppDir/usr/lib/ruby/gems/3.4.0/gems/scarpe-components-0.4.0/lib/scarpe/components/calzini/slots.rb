# frozen_string_literal: true

module Scarpe::Components::Calzini
  def slot_element(props, &block)
    HTML.render do |h|
      h.div((props["html_attributes"] || {}).merge(id: html_id, style: slot_style(props))) do
        h.div(style: { height: "100%", width: "100%" }, &block)
      end
    end
  end

  def flow_element(props, &block)
    HTML.render do |h|
      h.div((props["html_attributes"] || {}).merge(id: html_id, style: flow_style(props))) do
        h.div(style: { height: "100%", width: "100%", position: "relative" }, &block)
      end
    end
  end

  def stack_element(props, &block)
    HTML.render do |h|
      h.div((props["html_attributes"] || {}).merge(id: html_id, style: stack_style(props))) do
        h.div(style: { height: "100%", width: "100%", position: "relative" }, &block)
      end
    end
  end

  def documentroot_element(props, &block)
    flow_element(props, &block)
  end

  private

  def slot_style(props)
    styles = drawable_style(props)
    styles = background_style(props, styles)
    styles = border_style(props, styles)

    styles[:width] = dimensions_length(props["width"]) if props["width"]
    styles[:height] = dimensions_length(props["height"]) if props["height"]

    ## A new slot defines a new coordinate system, so absolutely-positioned children
    ## are relative to it. But that's going to need a lot of testing and Shoes3 comparison.
    #styles[:position] = "relative"

    styles
  end

  def flow_style(props)
    {
      display: "flex",
      "flex-direction": "row",
      "flex-wrap": "wrap",
      "align-content": "flex-start",
      "justify-content": "flex-start",
      "align-items": "flex-start",
    }.merge(slot_style(props))
  end

  def stack_style(props)
    {
      display: "flex",
      "flex-direction": "column",
      "align-content": "flex-start",
      "justify-content": "flex-start",
      "align-items": "flex-start",
      overflow: props["scroll"] ? "auto" : nil,
    }.compact.merge(slot_style(props))
  end

  def border_style(props, styles)
    bc = props["border_color"]
    return styles unless bc

    opts = props["options"] || {}

    border_style_hash = case bc
    when Range
      { "border-image": "linear-gradient(45deg, #{bc.first}, #{bc.last})" }
    when Array
      { "border-color": "rgba(#{bc.join(", ")})" }
    else
      { "border-color": bc }
    end
    styles.merge(
      "border-style": "solid",
      "border-width": "#{opts["strokewidth"] || 1}px",
      "border-radius": "#{opts["curve"] || 0}px",
    ).merge(border_style_hash)
  end

  def background_style(props, styles)
    bc = props["background_color"]
    return styles unless bc

    color = case bc
    when Array
      "rgba(#{bc.join(", ")})"
    when Range
      "linear-gradient(45deg, #{bc.first}, #{bc.last})"
    when ->(value) { File.exist?(value) }
      "url(data:image/png;base64,#{encode_file_to_base64(bc)})"
    else
      bc
    end

    styles.merge(background: color)
  end
end
