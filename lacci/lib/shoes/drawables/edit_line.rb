# frozen_string_literal: true

module Shoes
  # The `EditLine` class represents an editable text input field in a Shoes application.
  # @see https://github.com/scarpe-team/scarpe/tree/main/docs/examples/editline.rb

  class EditLine < Shoes::Drawable
    # Sets the styles for text content and width.
    shoes_styles :text, :width

    # Initializes a new `EditLine` instance.
    #
    # @param text [String] The initial text content of the EditLine.
    # @param width [Integer] (optional) The width of the EditLine in pixels.
    # @yield [new_text] Optional block to be executed when the text content changes.
    # @yieldparam new_text [String] The new text content of the EditLine.
    def initialize(text = "", width: nil, &block)
      super
      @block = block
      @text = text

      # Binds a "change" event to the EditLine, which triggers when the text content changes.
      bind_self_event("change") do |new_text|
        self.text = new_text
        @block&.call(new_text)
      end

      # Creates the display drawable for the EditLine.
      create_display_drawable
    end

    # Sets a block to be executed when the text content changes.
    #
    # @yield [new_text] Block to be executed when the text content changes.
    # @yieldparam new_text [String] The new text content of the EditLine.
    def change(&block)
      @block = block
    end
  end
end
