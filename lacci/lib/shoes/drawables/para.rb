# frozen_string_literal: true
require_relative 'font_helper.rb'
class Shoes
  class Para < Shoes::Drawable 
  include FontHelper
    shoes_styles :text_items, :size, :family, :font_weight, :font, :font_variant, :emphasis, :kerning, :weight, :wrap
    shoes_style(:stroke) { |val, _name| Shoes::Colors.to_rgb(val) }
    shoes_style(:fill) { |val, _name| Shoes::Colors.to_rgb(val) }

    # The manual's text styles (manual 1268-1286, 1366-1373, 1423-1441, 1489-1519;
    # ledger F4, F5, F10). variant is the manual's name; font_variant stays for Scarpe.
    shoes_styles :justify, :leading, :rise, :stretch, :variant
    shoes_style(:strikecolor) { |val, _name| Shoes::Colors.to_rgb(val) }
    shoes_style(:undercolor) { |val, _name| Shoes::Colors.to_rgb(val) }

    # Text cursor system (Shoes3 Para cursor/marker/hit)
    # text_cursor: integer character position of the caret, or nil (no cursor)
    # text_marker: integer character position of the selection anchor, or nil (no selection)
    shoes_styles :text_cursor, :text_marker

    include TextDecoration

    shoes_style(:align) do |val|
      unless ["left", "center", "right"].include?(val)
        raise(Shoes::Errors::InvalidAttributeValueError, "Align must be one of left, center or right!")
      end
      val
    end

    Shoes::Drawable.drawable_default_styles[Shoes::Para][:size] = :para

    # Title, Banner and the other kinds below are Paras to a display.
    def self.display_class_name
      "Para"
    end

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
    # Accepts integer (character position), :marker, or nil (remove the cursor and the marker).
    # :marker is Shoes 3.1's "drop the selection": with a marker set, the caret goes to the
    # start of the selection and the marker is cleared; with none, nothing changes
    # (s3t_textblock.c:602-616, ledger F14). Editors call it after every edit.
    # String/symbol values set the CSS cursor style directly (via Shoes style prop_change).
    #
    # @param val [Integer, Symbol, String, nil] the new cursor value
    def cursor=(val)
      case val
      when Integer
        self.text_cursor = val
      when :marker
        if @text_marker
          self.text_cursor = [@text_cursor, @text_marker].compact.min
          self.text_marker = nil
        end
      when nil
        self.text_cursor = nil
        self.text_marker = nil
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

    # The index of the character under (x, y), window coordinates as every click hands them
    # out (ledger H3), or nil off the text block: Shoes 3.1's TextBlock#hit (ledger F14).
    # A display that lays text out answers; others give the last index the pointer was over.
    #
    # @param x [Integer] the x coordinate
    # @param y [Integer] the y coordinate
    # @return [Integer, nil] the character index, or nil if not over the text block
    def hit(x, y)
      display = Shoes::DisplayService.display_service
      return display.para_hit(linkable_id, x, y) if display.respond_to?(:para_hit)

      Shoes::DisplayService.para_hit_cache[linkable_id]
    end

    # The top of the caret's line, measured in the slot that scrolls the para, so it compares
    # with that slot's scroll_top: Shoes 3.1's TextBlock#cursor_top, which editors keep their
    # caret in view with (ledger F14). 0 when the display cannot say.
    #
    # @return [Integer] the y-coordinate of the cursor position
    def cursor_top
      caret("top") || Shoes::DisplayService.para_cursor_top_cache[linkable_id] || 0
    end

    # The caret's left edge, measured as cursor_top is.
    #
    # @return [Integer, nil]
    def cursor_left
      caret("left")
    end

    private

    def caret(edge)
      display = Shoes::DisplayService.display_service
      display.para_caret(linkable_id)&.fetch(edge, nil) if display.respond_to?(:para_caret)
    end

    public

    protected

    # Shoes 3's text margins (ledger C9): 4 px on every side, and 12 below unless
    # margin or margin_bottom is given (s3t_textblock.c:108-110).
    def default_margins
      [4, 4, 4, @margin.nil? && @margin_bottom.nil? ? 12 : 4]
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
end

class Shoes
  # banner, title, subtitle, tagline, caption and inscription make text blocks of their
  # own classes (manual 1921-2129, ledger F2), so style(Shoes::Title, ...) styles titles
  # alone. Each is a Para at its own size (manual 3378-3384), and displays are told Para.
  { Banner: :banner, Title: :title, Subtitle: :subtitle, Tagline: :tagline,
    Caption: :caption, Inscription: :inscription }.each do |class_name, size|
    text_block = const_set(class_name, Class.new(Para))
    Shoes::Drawable.drawable_default_styles[text_block][:size] = size
  end
end
