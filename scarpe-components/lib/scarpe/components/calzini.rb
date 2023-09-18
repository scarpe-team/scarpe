# frozen_string_literal: true

require_relative "html"
require_relative "base64"

# Require all widget rendering code under calzini directory
Dir.glob("calzini/*.rb", base: __dir__) do |widget|
  require_relative widget
end

# The Calzini module expects to be included by a class defining
# the following methods:
#
#     * html_id - the HTML ID for the specific rendered DOM object
#     * handler_js_code(event_name) - the JS handler code for this DOM object and event name
#     * (optional) display_properties - the display properties for this object, unless overridden in render()
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

  def render(widget, properties = display_properties, &block)
    send("#{widget}_element", properties, &block)
  end

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

  def widget_style(props)
    styles = {}
    if props["hidden"]
      styles[:display] = "none"
    end
    styles
  end

  # Convert an [r, g, b, a] array to an HTML hex color code
  # Arrays support alpha. HTML hex does not. So premultiply.
  def rgb_to_hex(color)
    return color if color.nil?

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
