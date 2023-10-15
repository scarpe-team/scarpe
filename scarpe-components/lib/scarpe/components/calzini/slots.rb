# frozen_string_literal: true

module Scarpe::Components::Calzini
  def slot_element(props, &block)
    HTML.render do |h|
      h.div((props["html_attributes"] || {}).merge(id: html_id, style: slot_style(props)), &block)
    end
  end

  def flow_element(props, &block)
    HTML.render do |h|
      h.div((props["html_attributes"] || {}).merge(id: html_id, style: flow_style(props)), &block)
    end
  end

  def stack_element(props, &block)
    HTML.render do |h|
      h.div((props["html_attributes"] || {}).merge(id: html_id, style: stack_style(props)), &block)
    end
  end

  def documentroot_element(props, &block)
    HTML.render do |h|
      # DocumentRoot rendering intentionally uses flow styles.
      h.div((props["html_attributes"] || {}).merge(id: html_id, style: flow_style(props)), &block)
    end
  end

  private

  def slot_style(props)
    styles = drawable_style(props)
    styles = background_style(props, styles)
    styles = border_style(props, styles)
    styles = spacing_styles_for_attr("margin", props, styles)
    styles = spacing_styles_for_attr("padding", props, styles)

    styles[:width] = dimensions_length(props["width"]) if props["width"]
    styles[:height] = dimensions_length(props["height"]) if props["height"]

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

  SPACING_DIRECTIONS = [:left, :right, :top, :bottom]

  # We extract the appropriate margin and padding from the margin and
  # padding properties. If there are no margin or padding properties,
  # we fall back to props["options"] margin or padding, if it exists.
  #
  # Margin or padding (in either props or props["options"]) can be
  # a Hash with directions as keys, or an Array of left/right/top/bottom,
  # or a constant, which means all four are that constant. You can
  # also specify a "margin" plus "margin-top" which is constant but
  # margin-top is overridden, or similar.
  #
  # If any margin or padding property exists in props then we don't
  # check props["options"].
  def spacing_styles_for_attr(attr, props, styles, with_options: true)
    spacing_styles = {}

    case props[attr]
    when Hash
      props[attr].each do |dir, value|
        spacing_styles[:"#{attr}-#{dir}"] = dimensions_length value
      end
    when Array
      SPACING_DIRECTIONS.zip(props[attr]).to_h.compact.each do |dir, value|
        spacing_styles[:"#{attr}-#{dir}"] = dimensions_length(value)
      end
    when String, Numeric
      spacing_styles[attr.to_sym] = dimensions_length(props[attr])
    end

    SPACING_DIRECTIONS.each do |dir|
      if props["#{attr}_#{dir}"]
        spacing_styles[:"#{attr}-#{dir}"] = dimensions_length props["#{attr}_#{dir}"]
      end
    end

    unless spacing_styles.empty?
      return styles.merge(spacing_styles)
    end

    # We should see if there are spacing properties in props["options"],
    # unless we're currently doing that.
    if with_options && props["options"]
      spacing_styles = spacing_styles_for_attr(attr, props["options"], {}, with_options: false)
      styles.merge spacing_styles
    else
      # No "options" or we already checked it? Return the styles we were given.
      styles
    end
  end
end
