# frozen_string_literal: true

class Scarpe
  module Border
    def self.included(includer)
      includer.display_properties :border_color, :options
    end

    # Considering a signature like this:
    # border "#00D0FF", :strokewidth => 3, :curve => 12
    def border(color, options = {})
      @border_color = color
      @options = options
    end
  end

  module WebviewBorder
    def style
      styles = (super if defined?(super)) || {}
      return styles unless @border_color

      border_color = if @border_color.is_a?(Range)
        { "border-image": "linear-gradient(45deg, #{@border_color.first}, #{@border_color.last}) 1" }
      else
        { "border-color": @border_color }
      end

      styles.merge(
        "border-style": "solid",
        "border-width": "#{@options[:strokewidth] || 1}px",
        "border-radius": "#{@options[:curve] || 0}px",
      ).merge(border_color)
    end
  end
end
