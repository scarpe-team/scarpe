# frozen_string_literal: true

module Scarpe::Components::Calzini
  def background_element(props)
    HTML.render do |h|
      h.div(id: html_id, style: background_drawable_style(props))
    end
  end

  private

  def background_drawable_style(props)
    styles = {
      height: :inherit,
      width: :inherit,
      position: :absolute,
      top: 0,
      left: 0,
      'box-sizing': 'border-box',
      'pointer-events': 'none', # Allow clicks to pass through to elements below
      # A slot's Background drawables render as siblings placed after the
      # slot's own content div, not nested inside it (see stack/flow
      # rendering), so without an explicit stacking order they paint over
      # that content instead of behind it -- same concern mask_style
      # already handles for the same reason.
      'z-index': -1,
    }

    # Handle fill color - could be a solid color, gradient range, or RGBA array
    fill = props["fill"]

    fill_style = case fill
    when Range
      # Gradient background
      { "background": "linear-gradient(45deg, #{fill.first}, #{fill.last})" }
    when ->(value) { value.respond_to?(:angle) }
      # Gradient object with angle support
      { "background": "linear-gradient(#{css_gradient_angle(fill.angle)}deg, #{fill.first}, #{fill.last})" }
    when Array
      # RGBA array
      { "background-color": rgba_css(fill) }
    else
      # Simple color string
      { "background-color": fill }
    end

    styles = styles.merge(fill_style)

    # Add border-radius for curved corners
    if props["curve"] && props["curve"] > 0
      styles["border-radius"] = "#{props["curve"]}px"
    end

    # Allow height/width overrides
    if props["height"]
      h = props["height"]
      styles[:height] = h.is_a?(Numeric) ? "#{h}px" : h
    end
    if props["width"]
      w = props["width"]
      styles[:width] = w.is_a?(Numeric) ? "#{w}px" : w
    end

    styles.compact
  end
end
