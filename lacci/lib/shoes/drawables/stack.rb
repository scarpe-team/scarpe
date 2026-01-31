# frozen_string_literal: true

class Shoes
  class Stack < Shoes::Slot
    include Shoes::Background

    shoes_styles :scroll, :scroll_top

    shoes_events # No Stack-specific events

    def initialize(*args, **kwargs, &block)
      super

      create_display_drawable

      # Create the display-side drawable *before* running the block.
      # Then child drawables have a parent to add themselves to.
      @app.with_slot(self, &block) if block_given?
      fire_finish_callbacks
    end

    # Get or set the scroll position (pixels from top).
    # In Shoes, scroll_top is an accessor on scrollable stacks.
    def scroll_top
      @scroll_top || 0
    end

    def scroll_top=(value)
      @scroll_top = value.to_i
      send_self_event(value.to_i, event_name: "scroll_top")
    end
  end
end
