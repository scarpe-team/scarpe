# frozen_string_literal: true

class Scarpe
  module Background
    def background(color, options = {})
      @background = color
    end

    def style
      styles = (super if defined?(super)) || {}
      return styles unless @background

      styles.merge({ background: @background })
    end
  end
end
