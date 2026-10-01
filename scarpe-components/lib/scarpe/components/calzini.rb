# frozen_string_literal: true

require_relative "html"
require_relative "base64"
require_relative "errors"

# Require all drawable rendering code under calzini directory
Dir.glob("calzini/*.rb", base: __dir__) do |drawable|
  require_relative drawable
end

# The Calzini module expects to be included by a class defining
# the following methods:
#
#     * html_id - the HTML ID for the specific rendered DOM object
#     * handler_js_code(event_name) - the JS handler code for this DOM object and event name
#     * (optional) shoes_styles - the Shoes styles for this object, unless overridden in render()
module Scarpe::Components::Calzini
  extend self

  HTML = Scarpe::Components::HTML
  include Scarpe::Components::Base64

  SIZES = {
    inscription: 10,
    ins: 10,
    para: 12,
    caption: 14,
    tagline: 18,
    subtitle: 26,
    title: 34,
    banner: 48,
  }.freeze
  private_constant :SIZES

  # Render the Shoes drawable of type `drawable_name` with
  # the given properties to HTML and return it. If the
  # drawable type takes a block (e.g. Stack or Flow) then
  # the block will be properly rendered.
  #
  # @param drawable_name [String] the drawable name like "alert", "button" or "rect"
  # @param properties [Hash] a drawable-specific hash of property names to values
  # @block the block which, when called, will return the contents for drawable types with contents
  # @return [String] the rendered HTML
  def render(drawable_name, properties = shoes_styles, &block)
    send("#{drawable_name}_element", properties, &block)
  end

  # Return HTML for an empty page element, to be filled with HTML
  # renderings of the DOM tree.
  #
  # The wrapper-wvroot element is where Scarpe will fill in the
  # DOM element.
  #
  # @return [String] the rendered HTML for the empty page object.
  def empty_page_element
    <<~HTML
      <html>
        <head id='head-wvroot'>
          <style id='style-wvroot'>
            /** Style resets **/
            body {
              font-family: arial, Helvetica, sans-serif;
              margin: 0;
              height: 100%;
              overflow: hidden;
            }
            p {
              margin: 0;
            }
            #wrapper-wvroot {
              height: 100%;
              width: 100%;
            }
            /* Shoes Para text cursor (caret) blink animation */
            @keyframes shoesBlink {
              0%, 100% { opacity: 1; }
              50% { opacity: 0; }
            }
          </style>
        </head>
        <body id='body-wvroot'>
          <div id='wrapper-wvroot'></div>
        </body>
      </html>
    HTML
  end

  def text_size(sz)
    case sz
    when Numeric
      sz
    when Symbol
      SIZES[sz]
    when String
      SIZES[sz.to_sym] || sz.to_i
    else
      raise "Unexpected text size object: #{sz.inspect}"
    end
  end

  def dimensions_length(value)
    case value
    when Integer
      if value < 0
        "calc(100% - #{value.abs}px)"
      else
        "#{value}px"
      end
    when Float
      "#{value * 100}%"
    else
      value
    end
  end

  def drawable_style(props)
    styles = {}
    if props["hidden"]
      styles[:display] = "none"
    end

    # Do we need to set CSS positioning here, especially if displace is set? Position: relative maybe?
    # We need some Shoes3 screenshots and HTML-based tests here...

    if props["top"] || props["left"]
      styles[:position] = "absolute"
    end

    styles[:top] = dimensions_length(props["top"]) if props["top"]
    styles[:left] = dimensions_length(props["left"]) if props["left"]
    styles[:width] = dimensions_length(props["width"]) if props["width"]
    styles[:height] = dimensions_length(props["height"]) if props["height"]

    # Displace moves the drawable visually without affecting layout.
    # Uses CSS transform: translate() so the element's layout position is unchanged.
    if props["displace_left"] || props["displace_top"]
      dx = props["displace_left"] || 0
      dy = props["displace_top"] || 0
      styles[:transform] = "translate(#{dx}px, #{dy}px)"
      styles[:position] ||= "relative"
    end

    # Cursor style — map Shoes cursor names to CSS cursor values
    if props["cursor"]
      styles[:cursor] = shoes_cursor_to_css(props["cursor"])
    end
    styles[:"margin-left"] = dimensions_length(props["margin_left"]) if props["margin_left"]
    styles[:"margin-right"] = dimensions_length(props["margin_right"]) if props["margin_right"]
    styles[:"margin-top"] = dimensions_length(props["margin_top"]) if props["margin_top"]
    styles[:"margin-bottom"] = dimensions_length(props["margin_bottom"]) if props["margin_bottom"]


    
    styles = spacing_styles_for_attr("padding", props, styles)

    styles
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

  def first_color_of(*colors)
    colors.compact!
    colors.select! { |c| c != "" }
    rgb_to_hex(colors[0])
  end

  # Shoes measures a gradient's angle from the top, turning counter-clockwise, so 0
  # runs top to bottom and 90 left to right (manual 1073-1079). CSS measures from the
  # bottom, turning clockwise.
  def css_gradient_angle(shoes_angle)
    180 - shoes_angle
  end

  # Shoes colors carry alpha as an Integer from 0 to 255 (a Float alpha is
  # already a fraction). CSS rgba() wants the fraction.
  def rgba_css(color)
    r, g, b, a = color
    a = (a / 255.0).round(3) if a.is_a?(Integer)
    "rgba(#{[r, g, b, a].compact.join(", ")})"
  end

  # Convert an [r, g, b, a] array to an HTML hex color code
  # Arrays support alpha. HTML hex does not. So premultiply.
  def rgb_to_hex(color)
    return nil if color.nil?
    return "#000000" if color == ""

    # TODO: need to figure out if it's a color name like "aquamarine"
    # or a hex code or an image file to use as a pattern or what.
    return color if color.is_a?(String)

    # Handle Range objects (gradients) - extract the first color
    return rgb_to_hex(color.first) if color.is_a?(Range)

    # Handle Gradient objects (from Shoes::Colors::Gradient) - extract the first color
    # Gradient has color1/color2 attrs and first/last methods returning color strings
    if color.respond_to?(:color1) && color.respond_to?(:color2)
      return color.first  # Returns a color string like "rgb(255,0,0)"
    end

    r, g, b, a = *color
    if r.is_a?(Float)
      a ||= 1.0
      r_int = (r * 255.0).to_i.clamp(0, 255)
      g_int = (g * 255.0).to_i.clamp(0, 255)
      b_int = (b * 255.0).to_i.clamp(0, 255)
      a_float = a
    else
      a ||= 255
      r_int = r.to_i.clamp(0, 255)
      g_int = g.to_i.clamp(0, 255)
      b_int = b.to_i.clamp(0, 255)
      a_float = a / 255.0
    end

    # #RRGGBB has no alpha channel, so premultiplying RGB by alpha and
    # dropping alpha here would make any translucent -- and, worse, any
    # fully transparent ("nostroke", alpha 0) -- color indistinguishable
    # from an opaque one at that premultiplied RGB (0 alpha always
    # premultiplies to black, rendering as solid black text/fills instead
    # of invisible ones). Emit rgba() instead whenever alpha isn't opaque,
    # so the browser does the compositing with the real alpha.
    if a_float >= 1.0
      "#%0.2X%0.2X%0.2X" % [r_int, g_int, b_int]
    else
      "rgba(#{r_int}, #{g_int}, #{b_int}, #{a_float})"
    end
  end

  # Map Shoes cursor symbols to CSS cursor values
  SHOES_CURSOR_MAP = {
    arrow_cursor: "default",
    text_cursor: "text",
    watch_cursor: "wait",
    hand_cursor: "pointer",
    arrow: "default",
    hand: "pointer",
    text: "text",
    wait: "wait",
    crosshair: "crosshair",
    move: "move",
    help: "help",
    not_allowed: "not-allowed",
  }.freeze

  def shoes_cursor_to_css(cursor)
    case cursor
    when Symbol
      SHOES_CURSOR_MAP[cursor] || cursor.to_s.tr("_", "-")
    when String
      SHOES_CURSOR_MAP[cursor.to_sym] || cursor
    else
      "default"
    end
  end

  def degrees_to_radians(degrees)
    degrees * Math::PI / 180
  end

  def radians_to_degrees(radians)
    radians * (180.0 / Math::PI)
  end

  # Build an SVG transform string from draw_context settings.
  # Supports rotate, scale, and skew transforms.
  #
  # @param dc [Hash] the draw_context hash
  # @param center_x [Numeric] the x coordinate of the transform center
  # @param center_y [Numeric] the y coordinate of the transform center
  # @return [String,nil] the SVG transform string or nil if no transforms
  def build_svg_transform(dc, center_x = 0, center_y = 0)
    transforms = []
    
    if dc["rotate"]
      transforms << "rotate(#{dc["rotate"]}, #{center_x}, #{center_y})"
    end
    
    if dc["scale"]
      scale_x, scale_y = dc["scale"]
      scale_y ||= scale_x
      # Scale from center by translating, scaling, then translating back
      transforms << "translate(#{center_x}, #{center_y})"
      transforms << "scale(#{scale_x}, #{scale_y})"
      transforms << "translate(#{-center_x}, #{-center_y})"
    end
    
    if dc["skew"]
      skew_x, skew_y = dc["skew"]
      skew_y ||= 0
      # SVG skewX/skewY take angles in degrees
      transforms << "skewX(#{skew_x})" if skew_x && skew_x != 0
      transforms << "skewY(#{skew_y})" if skew_y && skew_y != 0
    end
    
    transforms.empty? ? nil : transforms.join(" ")
  end
end
