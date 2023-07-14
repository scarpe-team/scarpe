# frozen_string_literal: true

require "fastimage"
require "open-uri"

module Shoes
  class Image < Shoes::Widget
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
end

module Shoes
  class Widget
    def size
      width, height = FastImage.size(@url)

      [width, height]
    end
  end
end
