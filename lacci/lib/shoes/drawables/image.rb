# frozen_string_literal: true

class Shoes
  class Image < Shoes::Drawable
    shoes_styles :url, :width, :height, :top, :left, :click, :rotate_angle, :transform_origin
    shoes_events :click, :hover, :leave

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

    # Rotate this image by the given angle (in degrees).
    # In Shoes, image.rotate(angle) sets a persistent rotation.
    def rotate(angle)
      self.rotate_angle = angle
    end

    # Set the transform origin for this image.
    # In Shoes, image.transform(:center) sets rotation around the center.
    # Accepts :center, :corner (top-left), or a string CSS value.
    def transform(origin)
      case origin
      when :center, "center"
        self.transform_origin = "center"
      when :corner, "corner"
        self.transform_origin = "top left"
      else
        self.transform_origin = origin.to_s
      end
    end

    def size
      require "fastimage"
      width, height = FastImage.size(@url)

      [width, height]
    end
  end
end
