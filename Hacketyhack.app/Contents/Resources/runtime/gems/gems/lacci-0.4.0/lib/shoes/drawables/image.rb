# frozen_string_literal: true

class Shoes
  class Image < Shoes::Drawable
    shoes_styles :url, :width, :height, :top, :left, :click
    shoes_events # No Image-specific events yet

    init_args :url
    def initialize(*args, **kwargs)
      super

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
