# frozen_string_literal: true

class Scarpe
  class Button < Scarpe::Widget
    include Scarpe::Log
    display_properties :text, :width, :height, :top, :left, :color, :padding_top, :padding_bottom, :text_color, :size, :font_size

    # Initializes a new Button object.
    #
    # @param text [String] The text displayed on the button.
    # @param width [Integer] The width of the button in pixels.
    # @param height [Integer] The height of the button in pixels.
    # @param top [Integer] The position of the top edge of the button relative to its parent widget.
    # @param left [Integer] The position of the left edge of the button relative to its parent widget.
    # @param size [Integer] The font size of the button text.
    # @yield [] A block of code to be executed when the button is clicked.
    # @param color [String] The background color of the button.
    # @param padding_top [Integer] The padding above the button text.
    # @param padding_bottom [Integer] The padding below the button text.
    # @param text_color [String] The color of the button text.
    # How to Use
    #
    # To use the `Scarpe::Button` class, follow these steps:
    #
    # 1. Create a `Shoes.app` block.
    # 2. Inside the block, create a new instance of `Scarpe::Button` by calling `button` with the desired text as an argument. Assign it to a variable.
    # 3. Create any other necesary widgets and assign them to variables.
    # 4. Set the click handler for the button by calling `click` on the button varable and passing a block of code to be executed when the button is clicked.
    # 5. Within the click handler block, modify the desired widgets or perform any necessary actions.
    # 6. End the `Shoes.app` block.
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
    #
    # @see  https://github.com/scarpe-team/scarpe/blob/main/examples/button.rb
    def initialize(text, width: nil, height: nil, top: nil, left: nil, color: nil, padding_top: nil, padding_bottom: nil, size: 12, text_color: nil,
      font_size: nil, & block)

      log_init("Button")

      # Properties passed as positional args, not keywords, don't get auto-set
      @text = text
      @color = color

      @block = block

      super

      # Bind to a handler named "click"
      bind_self_event("click") do
        @log.debug("Button clicked, calling handler") if @block
        @block&.call
      end

      create_display_widget
    end

    # Sets the click handler for the button.
    #
    # @yield [] A block of code to be executed when the button is clicked.
    def click(&block)
      @block = block
    end
  end
end
