# frozen_string_literal: true

class Shoes
  class Para < Shoes::Drawable
    shoes_styles :text_items, :size, :font, :html_attributes, :hidden
    shoes_style(:stroke) { |val| Shoes::Colors.to_rgb(val) }

    shoes_events() # No Para-specific events yet

    # Initializes a new instance of the `Para` widget.
    #
    # @param args The text content of the paragraph.
    # @param stroke [String, nil] The color of the text stroke.
    # @param size [Symbol] The size of the paragraph text.
    # @param font [String, nil] The font of the paragraph text.
    # @param hidden [Boolean] Determines if the paragraph is initially hidden.
    # @param html_attributes [Hash] Additional HTML attributes for the paragraph.
    #
    # @example
    #    Shoes.app do
    #      p = para "Hello, This is at the top!", stroke: "red", size: :title, font: "Arial"
    #
    #      banner("Welcome to Shoes!")
    #      title("Shoes Examples")
    #      subtitle("Explore the Features")
    #      tagline("Step into a World of Shoes")
    #      caption("A GUI Framework for Ruby")
    #      inscription("Designed for Easy Development")
    #
    #      p.replace "On top we'll switch to ", strong("bold"), "!"
    #    end
    def initialize(*args, stroke: nil, size: :para, font: nil, **html_attributes)
      super

      # Text_children alternates strings and TextDrawables, so we can't just pass
      # it as a Shoes style. It won't serialize.
      update_text_children(args)

      @html_attributes = html_attributes || {}

      create_display_drawable
    end

    private

    def text_children_to_items(text_children)
      text_children.map { |arg| arg.is_a?(String) ? arg : arg.linkable_id }
    end

    public

    # Sets the paragraph text to a new value, which can
    # include {TextDrawable}s like em(), strong(), etc.
    #
    # @param children [Array] the arguments can be Strings and/or TextDrawables
    # @return [void]
    def replace(*children)
      update_text_children(children)
    end

    # Set the paragraph text to a single String.
    # To use bold, italics, etc. use {Para#replace} instead.
    #
    # @param child [String] the new text to use for this Para
    # @return [void]
    def text=(*children)
      update_text_children(children)
    end

    def text
      @text_children.map(&:to_s).join
    end

    def to_s
      self.text
    end

    private

    # Text_children alternates strings and TextDrawables, so we can't just pass
    # it as a Shoes style. It won't serialize.
    def update_text_children(children)
      @text_children = children.flatten
      # This should signal the display drawable to change
      self.text_items = text_children_to_items(@text_children)
    end
  end
end

class Shoes
  class Drawable
    def banner(*args, **kwargs)
      para(*args, **{ size: :banner }.merge(kwargs))
    end

    def title(*args, **kwargs)
      para(*args, **{ size: :title }.merge(kwargs))
    end

    def subtitle(*args, **kwargs)
      para(*args, **{ size: :subtitle }.merge(kwargs))
    end

    def tagline(*args, **kwargs)
      para(*args, **{ size: :tagline }.merge(kwargs))
    end

    def caption(*args, **kwargs)
      para(*args, **{ size: :caption }.merge(kwargs))
    end

    def inscription(*args, **kwargs)
      para(*args, **{ size: :inscription }.merge(kwargs))
    end

    alias_method :ins, :inscription
  end
end
