# frozen_string_literal: true

module Shoes
  class ListBox < Shoes::Drawable
    shoes_styles :items, :height, :width

    # Shoes3 uses choose as the initialize arg, and .choose(item) as the setter here,
    # but queries it with .text. So this is an unusual style, and we've chosen this
    # name not to conflict with Shoes3.
    shoes_style :chosen

    shoes_events :change

    def initialize(args = {}, &block)
      super

      @items = args[:items] || []
      @chosen = args[:choose] || args[:items]&.first

      bind_self_event("change") do |new_item|
        self.chosen = new_item
        @callback&.call(self)
      end

      create_display_drawable
    end

    # Select an item. `item` should be a text entry from `items`.
    #
    # @param item [String] the item to choose
    # @return [void]
    def choose(item)
      unless self.items.include?(item)
        raise Shoes::NoSuchListItemError, "List items (#{self.items.inspect}) do not contain item #{item.inspect}!"
      end
      @chosen = item
    end

    # The currently chosen text item or nil.
    #
    # @return [String|NilClass] the current text item or nil.
    def text
      @chosen
    end

    # Register a block to be called when the selection changes.
    #
    # @yield the block to be called when selection changes
    # @return [Shoes::ListBox] self
    def change(&block)
      @callback = block
      self # Allow chaining calls
    end
  end
end
