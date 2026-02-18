# frozen_string_literal: true
require_relative 'font_helper.rb'
class Shoes
  class Para < Shoes::Drawable 
  include FontHelper
    shoes_styles :text_items, :size, :family, :font_weight, :font, :font_variant, :emphasis, :kerning, :weight, :wrap
    shoes_style(:stroke) { |val, _name| Shoes::Colors.to_rgb(val) }
    shoes_style(:fill) { |val, _name| Shoes::Colors.to_rgb(val) }

    # Text cursor system (Shoes3 Para cursor/marker/hit)
    # text_cursor: integer character position of the caret, or nil (no cursor)
    # text_marker: integer character position of the selection anchor, or nil (no selection)
    shoes_styles :text_cursor, :text_marker

    UNDERLINE_VALUES = [nil, "none", "single", "double", "low", "error"]
    shoes_style :underline do |val, _name|
      unless UNDERLINE_VALUES.include?(val)
        raise Shoes::Errors::InvalidAttributeValueError, "Underline must be one of: #{UNDERLINE_VALUES.inspect}!"
      end
      val
    end

    STRIKETHROUGH_VALUES = [nil, "none", "single"]
    shoes_style :strikethrough do |val, _name|
      unless STRIKETHROUGH_VALUES.include?(val)
        raise Shoes::Errors::InvalidAttributeValueError, "Strikethrough must be one of: #{STRIKETHROUGH_VALUES.inspect}!"
      end
      val
    end

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

      if kwargs[:font]
        arr= parse_font(kwargs[:font])
        
        if arr[0] != nil

          kwargs[:emphasis] = arr[0]

        end

        if arr[1] != nil

          kwargs[:font_variant] = arr[1]

        end

        if arr[2] != nil

          kwargs[:font_weight] = arr[2]

        end

        if arr[3] != nil

          kwargs[:size] = arr[3]

        end

        if arr[4] != ""

          kwargs[:family] = arr[4]

        end

      end
 
      # Don't pass text_children args to Drawable#initialize
      super(*[], **kwargs)
        
      # Text_children alternates strings and TextDrawables, so we can't just pass
      # it as a Shoes style. It won't serialize.
      update_text_children(args)

      create_display_drawable
    end

    

    private

    def text_children_to_items(text_children)
      text_children.map { |arg| arg.is_a?(TextDrawable) ? arg.linkable_id : arg.to_s }
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

    # Return the raw contents of the para, including TextDrawables.
    # Unlike #text which returns plain text, this returns the original
    # array of strings and TextDrawable objects (em, strong, link, etc.)
    #
    # @return [Array<String, TextDrawable>] the text children
    def contents
      @text_children.dup
    end

    # --- Text Cursor System (Shoes3 Para cursor/marker/hit) ---

    # Get the text cursor position (integer character index).
    # This overrides the universal CSS cursor style for Para.
    # In Shoes3, para.cursor is always the text caret position.
    #
    # @return [Integer, nil] the cursor position, or nil if no cursor
    def cursor
      @text_cursor
    end

    # Set the text cursor position.
    # Accepts integer (character position), :marker (jump to marker), or nil (remove cursor).
    # String/symbol values set the CSS cursor style directly (via Shoes style prop_change).
    #
    # @param val [Integer, Symbol, String, nil] the new cursor value
    def cursor=(val)
      case val
      when Integer
        self.text_cursor = val
      when :marker
        self.text_cursor = @text_marker if @text_marker
      when nil
        self.text_cursor = nil
      else
        # For CSS cursor types (:text, :arrow, etc.), set the cursor style directly
        # We can't call super because method_missing would redefine cursor= on Para
        @cursor = val.to_s
        send_shoes_event({ "cursor" => @cursor }, event_name: "prop_change", target: linkable_id)
      end
    end

    # Get the selection marker position.
    #
    # @return [Integer, nil] the marker position, or nil if no selection
    def marker
      @text_marker
    end

    # Set the selection marker position.
    # When both cursor and marker are set, text between them is selected.
    #
    # @param val [Integer, nil] the new marker position, or nil to clear selection
    def marker=(val)
      self.text_marker = val
    end

    # Return the selection range as [start_position, length].
    # If no marker is set, returns [cursor_position, 0].
    #
    # @return [Array(Integer, Integer)] [start, length] of the selection
    def highlight
      c = @text_cursor || 0
      m = @text_marker
      return [c, 0] if m.nil?
      start = [c, m].min
      len = (c - m).abs
      [start, len]
    end

    # Hit-test: given pixel coordinates, return the character index at that position.
    # The display service pre-computes this on mouse events for paras with cursor mode.
    #
    # @param x [Integer] the x coordinate (page-relative)
    # @param y [Integer] the y coordinate (page-relative)
    # @return [Integer, nil] the character index, or nil if not over text
    def hit(x, y)
      Shoes::DisplayService.para_hit_cache[linkable_id]
    end

    # Return the vertical position (top) of the cursor in the para.
    # Useful for scroll tracking in editors.
    #
    # @return [Integer] the y-coordinate of the cursor position
    def cursor_top
      Shoes::DisplayService.para_cursor_top_cache[linkable_id] || 0
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

    # Alias for inscription (Shoes3 shorthand)
    alias_method :ins, :inscription
  end
end
