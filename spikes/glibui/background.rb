# frozen_string_literal: true

class Scarpe
  module GlimmerLibUIBackground
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
