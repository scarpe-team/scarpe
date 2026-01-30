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

  # Convert an [r, g, b, a] array to an HTML hex color code
  # Arrays support alpha. HTML hex does not. So premultiply.
  def rgb_to_hex(color)
    return nil if color.nil?
    return "#000000" if color == ""

    # TODO: need to figure out if it's a color name like "aquamarine"
    # or a hex code or an image file to use as a pattern or what.
    return color if color.is_a?(String)

    r, g, b, a = *color
    if r.is_a?(Float)
      a ||= 1.0
      r_float = r * a
      g_float = g * a
      b_float = b * a
    else
      a ||= 255
      a_float = (a / 255.0)
      r_float = (r.to_f / 255.0) * a_float
      g_float = (g.to_f / 255.0) * a_float
      b_float = (b.to_f / 255.0) * a_float
    end

    r_int = (r_float * 255.0).to_i.clamp(0, 255)
    g_int = (g_float * 255.0).to_i.clamp(0, 255)
    b_int = (b_float * 255.0).to_i.clamp(0, 255)

    "#%0.2X%0.2X%0.2X" % [r_int, g_int, b_int]
  end

  def degrees_to_radians(degrees)
    degrees * Math::PI / 180
  end

  def radians_to_degrees(radians)
    radians * (180.0 / Math::PI)
  end
end
