# frozen_string_literal: true

require "fastimage"
require "open-uri"

class Scarpe
  class Image < Scarpe::Widget
    display_properties :url, :width, :height, :top, :left, :click

    def initialize(url, width: nil, height: nil, top: nil, left: nil, click: nil)
      @url = url

      super

      # Get the image dimensions
      # @width, @height = size

      create_display_widget
    end

    def replace(url)
      self.url = url
    end
  end

  class Widget
    def size
      width, height = FastImage.size(@url)

      [width, height]
    end
  end
end
