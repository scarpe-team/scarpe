# frozen_string_literal: true

class Shoes
  class Button < Shoes::Drawable
    include Shoes::Log
    shoes_styles :text, :width, :height, :top, :left, :color, :padding_top, :padding_bottom, :text_color, :size, :font_size,:tooltip
    shoes_events :click, :hover

    # Creates a new Button object.
    #
    # @param text [String] The text displayed on the button.
    # @param width [Integer] The requested width of the button in pixels.
    # @param height [Integer] The requested height of the button in pixels.
    # @param top [Integer] The position of the top edge of the button relative to its parent widget.
    # @param left [Integer] The position of the left edge of the button relative to its parent widget.
    # @param size [Integer] The font size of the button text.
    # @param color [String] The background color of the button.
    # @param padding_top [Integer] The padding above the button text.
    # @param padding_bottom [Integer] The padding below the button text.
    # @param text_color [String] The color of the button text.
    # @yield A block of code to be executed when the button is clicked.
    # @return [Shoes::Button] the button object
    #
    # @example
    #   Shoes.app do
    #     @push = button "Push me"
    #     @note = para "Nothing pushed so far"
    #     @push.click {
    #       @note.replace(
    #         "Aha! Click! ",
    #         link("Go back") { @note.replace("Nothing pushed so far") }
    #       )
    #     }
    #   end
    def initialize(text, width: nil, height: nil, top: nil, left: nil, color: nil, padding_top: nil, padding_bottom: nil, size: 12, text_color: nil,
      font_size: nil,tooltip: nil, &block)

      log_init("Button")

      # Properties passed as positional args, not keywords, don't get auto-set
      @text = text
      @block = block

      super

      # Bind to a handler named "click"
      bind_self_event("click") do
        @log.debug("Button clicked, calling handler") if @block
        @block&.call
      end

      bind_self_event("hover") do
        @hover&.call
      end

      create_display_drawable
    end

    # Set the click handler
    #
    # @yield A block to be called when the button is clicked.
    def click(&block)
      @block = block
    end

    # Set the hover handler
    #
    # @yield A block to be called when the cursor moves to be over the button.
    def hover(&block)
      @hover = block
    end
  end
end
