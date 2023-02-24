# frozen_string_literal: true

class Scarpe
  module Background
    def self.included(includer)
      includer.display_property(:background_color)
    end

    # NOTE: this needs to be passed through in order for the styling to work
    def background(color, options = {})
      self.background_color = color
    end
  end

  module WebviewBackground
    def style
      styles = (super if defined?(super)) || {}
      return styles unless @background_color

      color = if @background_color.is_a?(Range)
        "linear-gradient(45deg, #{@background_color.first}, #{@background_color.last})"
      else
        @background_color
      end

      styles.merge(background: color)
    end
  end
end
