# frozen_string_literal: true

module Shoes
  class Image < Shoes::Drawable
    shoes_styles :url, :width, :height, :top, :left, :click

    def initialize(url, width: nil, height: nil, top: nil, left: nil, click: nil)
      super
      @url = url

      # Get the image dimensions
      # @width, @height = size

      create_display_drawable
    end

    def replace(url)
      self.url = url
    end

    def size
      require "fastimage"
      width, height = FastImage.size(@url)

      [width, height]
    end
  end
end
