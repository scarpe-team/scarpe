# frozen_string_literal: true

class Shoes
  class Button < Shoes::Drawable
    include Shoes::Focusable

    shoes_styles :text, :width, :height, :top, :left, :color, :padding_top, :padding_bottom, :text_color, :size, :font_size, :tooltip, :icon, :icon_pos, :font, :stroke
    shoes_style :state # nil, "readonly" or "disabled" (manual 1410-1421, ledger G4)
    shoes_events :click

    opt_init_args :text
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
    def initialize(*args, **kwargs, &block)
      super
      @click = block if block

      # The block is handed the button (manual 2918-2921, ledger G1)
      bind_self_event("click") do
        @click&.call(self)
      end

      create_display_drawable
    end

    # Set the click handler
    #
    # @yield [button] A block to be called with the button when it is clicked.
    # @return [self]
    def click(&block)
      @click = block
      self
    end
  end
end
