# frozen_string_literal: true

require "scarpe/components/named_colors"

class Shoes
  module Colors
    extend self

    COLORS = Scarpe::Components::NamedColors::COLORS
    # COLORS is public — classic Shoes exposes Shoes::COLORS for apps
    # like Hackety Hack that enumerate color names.

    class << self
      def included(base)
        COLORS.each do |color, rgb|
          base.define_method(color) do |alpha = 255|
            rgb + [alpha]
          end
        end
      end
    end

    # https://github.com/shoes/shoes3/blob/b856f28795112ecb64bc8f891ac166675f059beb/static/manual-en.txt#L839-L847
    def gray(darkness = 128, alpha = nil)
      alpha ||= (darkness.is_a?(Integer) ? 255 : 1.0)
      [darkness, darkness, darkness, alpha]
    end

    # Shoes allows RGB values to be Floats between 0 and 1 or Integers between 0 and 255
    def rgb(r, g, b, a = nil)
      if r.is_a?(Float)
        [r, g, b, a || 1.0]
      elsif r.is_a?(Integer)
        [r, g, b, a || 255]
      else
        raise("RGB values should be Float or Integer!")
      end
    end

    # In Shoes, gradient(color1, color2) creates a gradient pattern.
    # Returns a Gradient object that display services can render as CSS gradients.
    # Supports :angle option for gradient direction (in degrees).
    def gradient(color1, color2, **opts)
      c1 = to_rgb(color1) rescue color1
      c2 = to_rgb(color2) rescue color2

      c1_str = c1.is_a?(Array) ? "rgb(#{c1[0]},#{c1[1]},#{c1[2]})" : c1.to_s
      c2_str = c2.is_a?(Array) ? "rgb(#{c2[0]},#{c2[1]},#{c2[2]})" : c2.to_s

      Gradient.new(c1_str, c2_str, opts[:angle])
    end

    # Simple gradient class to hold colors and angle for rendering.
    class Gradient
      attr_reader :color1, :color2, :angle

      def initialize(color1, color2, angle = nil)
        @color1 = color1
        @color2 = color2
        @angle = angle || 45  # Default to 45 degrees like current behavior
      end

      # For backwards compatibility with simple string handling
      def to_s
        "#{@color1}-#{@color2}"
      end

      # Support Range-like first/last for Calzini compatibility
      def first
        @color1
      end

      def last
        @color2
      end
    end

    def to_rgb(color)
      case color
      when nil
        nil
      when Array
        color # Already an RGB array
      when Symbol
        if COLORS[color]
          rgb(*COLORS[color])
        else
          raise("Unrecognised color name: #{color}")
        end
      when String
        if color[0] == "#"
          if color.length == 4
            r = color[1].to_i(16)
            g = color[2].to_i(16)
            b = color[3].to_i(16)
            rgb(16 * r, 16 * g, 16 * b)
          elsif color.length == 7
            r = color[1..2].to_i(16)
            g = color[3..4].to_i(16)
            b = color[5..6].to_i(16)
            rgb(r, g, b)
          else
            raise("Don't know how to convert #{color.inspect} to RGB! (wrong number of digits)")
          end
        else
          rgb_value = COLORS[color.to_sym]
          if rgb_value
            rgb(*rgb_value)
          else
            raise("Unrecognised color name: #{color}")
          end
        end
      else
        raise("Don't know how to convert #{color.inspect} to RGB!")
      end
    end
  end

  # Shoes3 exposes Shoes::COLORS at the top level for apps like Hackety Hack
  COLORS = Colors::COLORS
end
