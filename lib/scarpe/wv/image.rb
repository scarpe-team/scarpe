# frozen_string_literal: true

require "base64"
require "uri"

class Scarpe
  class WebviewImage < WebviewWidget
    def initialize(properties)
      super

      @url = valid_url?(@url) ? @url : "data:image/png;base64,#{encode_image_to_base64(@url)}"
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

    def valid_url?(string)
      uri = URI.parse(string)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError, URI::BadURIError
      false
    end

    def encode_image_to_base64(image_filename)
      directory_path = File.dirname(__FILE__, 4)

      image_path = File.join(directory_path, image_filename)

      image_data = File.binread(image_path)

      encoded_data = Base64.strict_encode64(image_data)

      encoded_data
    end

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
