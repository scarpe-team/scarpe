# frozen_string_literal: true

class Scarpe
  class Para < Scarpe::Widget
    class << self
      def inherited(subclass)
        Scarpe::Widget.widget_classes ||= []
        Scarpe::Widget.widget_classes << subclass
        super
      end
    end

    # Define the display properties for the `Para` widget.
    display_properties :text_items, :stroke, :size, :font, :html_attributes, :hidden

    # Initializes a new instance of the `Para` widget.
    #
    # @param args The text content of the paragraph.
    # @param stroke [String, nil] The color of the text stroke.
    # @param size [Symbol] The size of the paragraph text.
    # @param font [String, nil] The font of the paragraph text.
    # @param hidden [Boolean] Determines if the paragraph is initially hidden.
    # @param html_attributes [Hash] Additional HTML attributes for the paragraph.
    # How to Use
    #
    # To use the Scarpe::Para class, follow these steps:
    #
    # 1. Create a Scarpe::Para instance by calling Scarpe::Para.new and provide the desired text as arguments. Assign it to a variable.
    # 2. Customize the paragraph by setting optional properties such as stroke, size, font, and hidden.
    # 3. Replace or modify the paragraph content by calling the replace method and passing new text as arguments.
    # 4. Hide the paragraph by calling the hide method.
    # 5. Show the hidden paragraph by calling the show method.
    #
    # @example
    #    Shoes.app do
    #      para_widget = para "Hello, This is title!", stroke: "red", size: :title, font: "Arial"
    #      @btn = button "toogle title🪄" ,color:"#FF7116",padding_bottom:"8",padding_top:"8",text_color:"white"
    #
    #      toggle = true
    #
    #      @btn.click do
    #        toggle = !toggle
    #        if toggle
    #           para_widget.show
    #        else
    #           para_widget.hide
    #        end
    #       end
    #
    #       @btn2 = button "replace title🪄" ,color:"#FF7116",padding_bottom:"8",padding_top:"8",text_color:"white"
    #
    #       @btn2.click do
    #          para_widget.replace("Welcome!")
    #       end
    #
    #       banner_widget = banner("Welcome to Shoes!")
    #       title_widget = title("Shoes Examples")
    #       subtitle_widget = subtitle("Explore the Features")
    #       tagline_widget = tagline("Step into a World of Shoes")
    #       caption_widget = caption("A GUI Framework for Ruby")
    #       inscription_widget = inscription("Designed for Easy Development")
    #
    #      end
    #
    # @see  https://github.com/scarpe-team/scarpe/blob/main/examples/para.rb
    def initialize(*args, stroke: nil, size: :para, font: nil, hidden: false, **html_attributes)
      puts "para args: #{args}"
      @text_children = args || []

      # If the paragraph is hidden, store the text items in `@hidden_text_items` and set `@text_items` to an empty array.
      # Otherwise, store the text items in `@text_items` and set `@hidden_text_items` to an empty array.
      if hidden
        @hidden_text_items = text_children_to_items(@text_children)
        @text_items = []
      else
        @text_items = text_children_to_items(@text_children)
        @hidden_text_items = []
      end

      # Convert the stroke color to RGB.
      stroke = to_rgb(stroke)

      @html_attributes = html_attributes || {}

      super

      create_display_widget
    end

    # Converts the text children into an array of text items.
    # @param The text children of the paragraph.
    # @return [Array<String, Integer>] The text items.
    def text_children_to_items(text_children)
      text_children.map { |arg| arg.is_a?(String) ? arg : arg.linkable_id }
    end

    # Replaces the children of the paragraph with the specified text children.
    # @param children [Array<String, Scarpe::TextWidget>] The new text children.
    def replace(*children)
      @text_children = children

      # This should signal the display widget to change
      self.text_items = text_children_to_items(@text_children)
    end

    # Hides the paragraph by setting the text items to an empty array.
    def hide
      # Idempotent: return if already hidden
      return unless @hidden_text_items.empty?

      @hidden_text_items = self.text_items
      self.text_items = []
    end

    # Shows the hidden paragraph by restoring the text items.
    def show
      # Idempotent: return if already shown
      return unless self.text_items.empty?

      self.text_items = @hidden_text_items
      @hidden_text_items = []
    end
  end

  # The `Widget` class is the base class for all widgets in Scarpe.
  class Widget
    # Creates a banner widget with thespecified text and options.
    # @param args  The text content of the banner.
    # @param kwargs [Hash] Additional options for the banner.
    def banner(*args, **kwargs)
      para(*args, **{ size: :banner }.merge(kwargs))
    end

    # Creates a title widget with the specified text and options.
    # @param args The text content of the title.
    # @param kwargs [Hash] Additional options for the title.
    def title(*args, **kwargs)
      para(*args, **{ size: :title }.merge(kwargs))
    end

    # Creates a subtitle widget with the specified text and options.
    # @param args  The text content of the subtitle.
    # @param kwargs [Hash] Additional options for the subtitle.
    def subtitle(*args, **kwargs)
      para(*args, **{ size: :subtitle }.merge(kwargs))
    end

    # Creates a tagline widget with the specified text and options.
    # @param args The text content of the tagline.
    # @param kwargs [Hash] Additional options for the tagline.
    def tagline(*args, **kwargs)
      para(*args, **{ size: :tagline }.merge(kwargs))
    end

    # Creates a caption widget with the specified text and options.
    # @param args The text content of the caption.
    # @param kwargs [Hash] Additional options for the caption.
    def caption(*args, **kwargs)
      para(*args, **{ size: :caption }.merge(kwargs))
    end

    # Creates an inscription widget with the specified text and options.
    # @param args The text content of the inscription.
    # @param kwargs [Hash] Additional options for the inscription.
    def inscription(*args, **kwargs)
      para(*args, **{ size: :inscription }.merge(kwargs))
    end

    # Alias for the `inscription` method.
    alias_method :ins, :inscription
  end
end
