# frozen_string_literal: true

class Shoes
  class Para < Shoes::Drawable
    shoes_styles :text_items, :size, :font
    shoes_style(:stroke) { |val| Shoes::Colors.to_rgb(val) }

    shoes_style(:align) do |val|
      unless ["left", "center", "right"].include?(val)
        raise(Shoes::Errors::InvalidAttributeValueError, "Align must be one of left, center or right!")
      end
      val
    end

    Shoes::Drawable.drawable_default_styles[Shoes::Para][:size] = :para

    shoes_events # No Para-specific events yet

    # Initializes a new instance of the `Para` drawable. There are different
    # methods to instantiate slightly different styles of Para, such as
    # `tagline`, `caption` and `subtitle`. These will always be different
    # sizes, but may be generally styled differently for some display services.
    #
    # @param args The text content of the paragraph.
    # @param kwargs [Hash] the various Shoes styles for this paragraph.
    #
    # @example
    #    Shoes.app do
    #      p = para "Hello, This is at the top!", stroke: red, size: :title, font: "Arial"
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
    def initialize(*args, **kwargs)
      # Don't pass text_children args to Drawable#initialize
      super(*[], **kwargs)

      # Text_children alternates strings and TextDrawables, so we can't just pass
      # it as a Shoes style. It won't serialize.
      update_text_children(args)

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

    # Return the text, but not the styling, of the para's
    # contents. For example, if the contents had strong
    # and emphasized text, the bold and emphasized would
    # be removed but the text would be returned.
    #
    # @return [String] the text from this para
    def text
      @text_children.map(&:to_s).join
    end

    # Return the text but not styling from the para. This
    # is the same as #text.
    #
    # @return [String] the text from this para
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
    # Return a banner-sized para. This can use all the normal
    # Para styles and arguments. See {Para#initialize} for
    # details.
    #
    # @return [Shoes::Para] the new para drawable
    def banner(*args, **kwargs)
      para(*args, **{ size: :banner }.merge(kwargs))
    end

    # Return a title-sized para. This can use all the normal
    # Para styles and arguments. See {Para#initialize} for
    # details.
    #
    # @return [Shoes::Para] the new para drawable
    def title(*args, **kwargs)
      para(*args, **{ size: :title }.merge(kwargs))
    end

    # Return a subtitle-sized para. This can use all the normal
    # Para styles and arguments. See {Para#initialize} for
    # details.
    #
    # @return [Shoes::Para] the new para drawable
    def subtitle(*args, **kwargs)
      para(*args, **{ size: :subtitle }.merge(kwargs))
    end

    # Return a tagline-sized para. This can use all the normal
    # Para styles and arguments. See {Para#initialize} for
    # details.
    #
    # @return [Shoes::Para] the new para drawable
    def tagline(*args, **kwargs)
      para(*args, **{ size: :tagline }.merge(kwargs))
    end

    # Return a caption-sized para. This can use all the normal
    # Para styles and arguments. See {Para#initialize} for
    # details.
    #
    # @return [Shoes::Para] the new para drawable
    def caption(*args, **kwargs)
      para(*args, **{ size: :caption }.merge(kwargs))
    end

    # Return an inscription-sized para. This can use all the normal
    # Para styles and arguments. See {Para#initialize} for
    # details.
    #
    # @return [Shoes::Para] the new para drawable
    def inscription(*args, **kwargs)
      para(*args, **{ size: :inscription }.merge(kwargs))
    end

    alias_method :ins, :inscription
  end
end
