# frozen_string_literal: true

class Shoes
  class Stack < Shoes::Slot
    include Shoes::Background
    include Shoes::Border
    include Shoes::Spacing

    # TODO: sort out various margin and padding properties, including putting stuff into spacing
    shoes_styles :width, :height, :scroll

    shoes_events() # No Stack-specific events yet

    def initialize(width: nil, height: nil, margin: nil, padding: nil, scroll: false, margin_top: nil, margin_bottom: nil, margin_left: nil,
      margin_right: nil, **options, &block)

      @options = options

      super

      create_display_drawable
      # Create the display-side drawable *before* running the block, which will add child drawables with their display drawables
      Shoes::App.instance.with_slot(self, &block) if block_given?
    end
  end
end
