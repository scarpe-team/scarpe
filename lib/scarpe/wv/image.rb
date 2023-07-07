# frozen_string_literal: true

require "scarpe/base64"

class Scarpe
  class WebviewImage < WebviewWidget
    include Base64
    def initialize(properties)
      super

      @url = valid_url?(@url) ? @url : "data:image/png;base64,#{encode_file_to_base64(@url)}"
    end

    def element
      if @click
        HTML.render do |h|
          h.a(id: html_id, href: @click) { h.img(id: html_id, src: @url, style:) }
        end
      else
        HTML.render do |h|
          h.img(id: html_id, src: @url, style:)
        end
      end
    end

    private

    def style
      styles = {}

      styles[:width] = Dimensions.length(@width) if @width
      styles[:height] = Dimensions.length(@height) if @height

      styles[:top] = Dimensions.length(@top) if @top
      styles[:left] = Dimensions.length(@left) if @left
      styles[:position] = "absolute" if @top || @left

      styles
    end
  end
end
