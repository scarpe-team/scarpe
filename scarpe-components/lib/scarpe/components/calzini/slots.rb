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
        # Using display:contents so the wrapper is transparent to flexbox layout
        # This allows flex-wrap to work on direct children (buttons, etc.)
        h.div(style: { height: "100%", width: "100%", position: "relative", display: "contents" }, &block)
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

  def mask_element(props, &block)
    HTML.render do |h|
      h.div((props["html_attributes"] || {}).merge(id: html_id, style: mask_style(props))) do
        h.div(style: { height: "100%", width: "100%", position: "relative" }, &block)
      end
    end
  end

  def documentroot_element(props, &block)
    flow_element(props, &block)
  end

  private

  def mask_style(props)
    # The mask container is positioned absolutely over the parent, initially visible
    # so child elements are laid out. JavaScript will hide it after extracting content.
    {
      position: "absolute",
      top: "0",
      left: "0",
      width: "100%",
      height: "100%",
      overflow: "hidden",
      opacity: "0",
      "pointer-events": "none",
      "z-index": "-1",
    }.merge(slot_style(props))
  end

  def slot_style(props)
    styles = drawable_style(props)
    styles = background_style(props, styles)
    styles = border_style(props, styles)

    styles[:width] = dimensions_length(props["width"]) if props["width"]
    styles[:height] = dimensions_length(props["height"]) if props["height"]

    # Handle :attach style for absolute positioning
    # :attach => Window positions relative to the window (absolute)
    # :attach => :center centers the slot
    attach = props["attach"]
    if attach
      attach_value = attach.is_a?(String) ? attach : attach.to_s
      if attach_value =~ /window/i || attach_value == "Shoes::Window"
        # Absolute positioning relative to window
        styles[:position] = "absolute"
      elsif attach_value == "center" || attach_value == ":center"
        # Center the slot
        styles[:position] = "absolute"
        styles[:left] = "50%"
        styles[:top] = "50%"
        styles[:transform] = "translate(-50%, -50%)"
      end
      # Other attach values (another drawable) would need more complex handling
    end

    # Slots need position:relative so that absolutely-positioned children
    # (like Border drawables) anchor to their parent slot, not the window.
    styles[:position] = "relative" unless styles[:position]

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
      overflow: props["scroll"] ? "auto" : nil,
    }.compact.merge(slot_style(props))
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
    when ->(value) { value.respond_to?(:angle) }
      # Gradient object with angle support
      { "border-image": "linear-gradient(#{bc.angle}deg, #{bc.first}, #{bc.last})" }
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
    when ->(value) { value.respond_to?(:angle) }
      # Gradient object with angle support
      "linear-gradient(#{bc.angle}deg, #{bc.first}, #{bc.last})"
    when ->(value) { File.exist?(value) }
      "url(data:image/png;base64,#{encode_file_to_base64(bc)})"
    when ->(value) { valid_url?(value) }
      "url(#{bc})"
    else
      bc
    end

    styles.merge(background: color)
  end
end
