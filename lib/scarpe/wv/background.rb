# frozen_string_literal: true

require "scarpe/components/base64"

module Scarpe::Webview
  module Background
    include Scarpe::Components::Base64

    def style
      styles = (super if defined?(super)) || {}
      return styles unless @background_color

      color = case @background_color
      when Array
        "rgba(#{@background_color.join(", ")})"
      when Range
        "linear-gradient(45deg, #{@background_color.first}, #{@background_color.last})"
      when ->(value) { File.exist?(value) }
        "url(data:image/png;base64,#{encode_file_to_base64(@background_color)})"
      else
        @background_color
      end

      styles.merge(background: color)
    end
  end
end
