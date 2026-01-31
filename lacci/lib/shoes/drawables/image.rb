# frozen_string_literal: true

class Shoes
  class Image < Shoes::Drawable
    shoes_styles :url, :width, :height, :top, :left, :click
    shoes_events # No Image-specific events yet

    init_args :url
    def initialize(*args, **kwargs)
      # In Shoes, image can be called with positional width/height:
      # image(width, height) { ... } — block-based image with dimensions
      # image(url, width: w, height: h) — normal image
      # When first arg is numeric, treat as image(width, height, &block)
      if args.length >= 2 && args[0].is_a?(Numeric) && args[1].is_a?(Numeric)
        kwargs[:width] = args[0]
        kwargs[:height] = args[1]
        args = args[2..] || []
        # If no URL, set a blank/placeholder
        args = [""] if args.empty?
      end

      super(*args, **kwargs)

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
