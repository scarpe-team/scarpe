# frozen_string_literal: true

class Shoes
  # An image from a file or URL, or a canvas: image(w, h) { ... } runs its block with
  # the image as the current slot, so the shapes and text drawn there are the image's
  # children and are painted inside its box (manual 410-426, ledger E9).
  class Image < Shoes::Drawable
    include Shoes::DrawContext

    shoes_styles :url, :width, :height, :top, :left, :click, :rotate_angle, :transform_origin
    # What a screen reader calls the picture (EXT, ledger N1); Shoes 3 left images unnamed.
    shoes_style :alt
    shoes_events :click, :hover, :leave

    init_args :url
    def initialize(*args, **kwargs, &block)
      # image(width, height) { ... } and image(styles) { ... } are canvases with no file.
      if args.length >= 2 && args[0].is_a?(Numeric) && args[1].is_a?(Numeric)
        kwargs[:width], kwargs[:height], *args = args
      end
      canvas = block && !args.first.is_a?(String)
      args = [""] if args.empty?

      super(*args, **kwargs)

      create_display_drawable

      # A click block is heard like a shape's (Drawable#click, ledger E8): the display is
      # told has_click, so a press on an empty slot over the picture reaches it too.
      bind_self_event("hover") do
        @hover_handler&.call(self)
      end

      bind_self_event("leave") do
        @leave_handler&.call(self)
      end

      # Shoes 3 takes a file image's block as its click (simple-bounce.rb, mask2.rb).
      if canvas
        @app.with_slot(self, &block)
      elsif block
        click(&block)
      end
    end

    # What was drawn on the image. Do not call add_child or remove_child directly,
    # use set_parent.
    def children
      @children ||= []
    end

    def contents
      children.dup
    end

    def add_child(child)
      children << child
    end

    def remove_child(child)
      children.delete(child)
    end

    def destroy
      children.dup.each(&:destroy)
      super
    end

    # Set the hover handler. Returns self for method chaining.
    def hover(&block)
      @hover_handler = block
      self
    end

    # Set the leave handler. Returns self for method chaining.
    def leave(&block)
      @leave_handler = block
      self
    end

    def replace(url)
      self.url = url
    end

    # The file name or URL of the picture (manual 3158-3160).
    #
    # @return [String]
    def path
      @url
    end

    # Swap in a different picture, from a file or URL (manual 3162-3164).
    def path=(new_path)
      self.url = new_path
    end

    # The width stored in the file, whatever size the image is shown at (manual 3153-3156).
    #
    # @return [Integer, nil] nil for a canvas or a file that is not a picture
    def full_width
      size.first
    end

    # The height stored in the file (manual 3143-3151). See #full_width.
    #
    # @return [Integer, nil]
    def full_height
      size.last
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
