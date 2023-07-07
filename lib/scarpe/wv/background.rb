# frozen_string_literal: true

require "scarpe/base64"
class Scarpe
  module WebviewBackground
    include Base64
    def style
      styles = (super if defined?(super)) || {}
      return styles unless @background_color

      color = if @background_color.is_a?(Range)
        "linear-gradient(45deg, #{@background_color.first}, #{@background_color.last})"
      elsif File.exist?(@background_color)
        # @background_color is a valid file path
        "url(data:image/png;base64,#{encode_file_to_base64(@background_color)})"
      else
        @background_color
      end

      styles.merge(background: color)
    end
  end
end
