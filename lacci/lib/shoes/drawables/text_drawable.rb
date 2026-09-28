# frozen_string_literal: true

class Shoes
  # underline and strikethrough, for text blocks and the fragments inside them.
  #
  # A style that sets one to nil or false means "none", and says so on the wire, so a
  # display drops its own default (a link's underline) instead of reading nil as
  # "unset" (wire contract (d); style(Link, underline: nil) in accordion.rb). true is
  # "single" (ledger F6).
  module TextDecoration
    UNDERLINES = ["none", "single", "double", "low", "error"].freeze
    STRIKETHROUGHS = ["none", "single"].freeze
    SWITCHES = { nil => "none", false => "none", true => "single" }.freeze

    def self.included(text_class)
      text_class.shoes_style(:underline) { |value, _name| TextDecoration.pick(value, UNDERLINES, "Underline") }
      text_class.shoes_style(:strikethrough) { |value, _name| TextDecoration.pick(value, STRIKETHROUGHS, "Strikethrough") }
    end

    def self.pick(value, allowed, name)
      value = SWITCHES.fetch(value) { value.to_s }
      return value if allowed.include?(value)

      raise Shoes::Errors::InvalidAttributeValueError, "#{name} must be one of: #{allowed.inspect}!"
    end
  end

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
    shoes_styles :justify, :rise, :stretch, :strikecolor, :variant # as on text blocks (ledger F5)
    shoes_styles :weight, :family, :emphasis, :kerning # the manual lists span for these too (F5)
    include TextDecoration

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

    # Return the raw contents, including nested TextDrawables.
    # Unlike #text which returns plain text, this returns the original
    # array of strings and TextDrawable objects.
    #
    # @return [Array<String, TextDrawable>] the text children
    def contents
      @text_children.dup
    end

    # The text block or fragment this fragment sits in, as Shoes 3's cText#parent is
    # (s3t_text.c:72-83, ledger F13): nil until a para or a fragment takes it as text.
    # Hackety Hack's links recolour their para through it.
    #
    # @return [Shoes::Para, Shoes::TextDrawable, nil]
    def parent
      @parent || @text_parent
    end

    # The para or fragment that takes this fragment as text says so here.
    def text_parent=(holder)
      @text_parent = holder
    end

    private

    # Text_children alternates strings and TextDrawables, so we can't just pass
    # it as a Shoes style. It won't serialize.
    def update_text_children(children)
      @text_children = children.flatten.map { |child| utf8_text(child) }
      @text_children.each { |child| child.text_parent = self if child.is_a?(TextDrawable) }
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
