# frozen_string_literal: true

class Shoes
  # TextDrawable is the parent class of various classes of
  # text that can go inside a para. This includes normal
  # text, but also links, italic text, bold text, etc.
  #
  # In Shoes3 this corresponds to cText, and it would
  # have methods app, contents, children, parent,
  # style, to_s, text, text= and replace.
  #
  # Much of what this does and how is similar to Para.
  # It's a very similar API.
  class TextDrawable < Shoes::Drawable
    shoes_styles :text_items, :size, :stroke, :strokewidth, :fill, :undercolor, :font

    STRIKETHROUGH_VALUES = [nil, "none", "single"]
    shoes_style :strikethrough do |val, _name|
      unless STRIKETHROUGH_VALUES.include?(val)
        raise Shoes::Errors::InvalidAttributeValueError, "Strikethrough must be one of: #{STRIKETHROUGH_VALUES.inspect}!"
      end
      val
    end

    UNDERLINE_VALUES = [nil, "none", "single", "double", "low", "error"]
    shoes_style :underline do |val, _name|
      unless UNDERLINE_VALUES.include?(val)
        raise Shoes::Errors::InvalidAttributeValueError, "Underline must be one of: #{UNDERLINE_VALUES.inspect}!"
      end
      val
    end

    shoes_events # No TextDrawable-specific events yet

    def initialize(*args, **kwargs)
      # Don't pass text_children args to Drawable#initialize
      super(*[], **kwargs)

      # Text_children alternates strings and TextDrawables, so we can't just pass
      # it as a Shoes style. It won't serialize.
      update_text_children(args)

      create_display_drawable
    end

    def text_children_to_items(text_children)
      text_children.map { |arg| arg.is_a?(TextDrawable) ? arg.linkable_id : arg.to_s }
    end

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

  class << self
    def default_text_drawable_with(element)
      class_name = element.capitalize

      drawable_class = Class.new(Shoes::TextDrawable) do
        shoes_events # No specific events

        init_args # We're going to pass an empty array to super
      end
      Shoes.const_set class_name, drawable_class
    end
  end
end

Shoes.default_text_drawable_with(:code)
Shoes.default_text_drawable_with(:del)
Shoes.default_text_drawable_with(:em)
Shoes.default_text_drawable_with(:strong)
Shoes.default_text_drawable_with(:span)
Shoes.default_text_drawable_with(:sub)
Shoes.default_text_drawable_with(:sup)
Shoes.default_text_drawable_with(:ins) # in Shoes3, looks like "ins" is just underline

# Defaults must come *after* classes are defined

Shoes::Drawable.drawable_default_styles[Shoes::Ins][:underline] = "single"
