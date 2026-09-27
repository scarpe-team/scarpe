# frozen_string_literal: true

class Shoes
  class ListBox < Shoes::Drawable
    include Shoes::Focusable

    shoes_styles :items, :height, :width, :font, :stroke
    shoes_style :change # the handler (manual 1123-1128, ledger G10)
    shoes_style :state # nil, "readonly" or "disabled" (manual 1410-1421, ledger G4)

    # Shoes3 uses choose as the initialize arg, and .choose(item) as the setter here,
    # but queries it with .text. So this is an unusual style, and we've chosen this
    # name not to conflict with Shoes3.
    shoes_style :chosen

    shoes_events :change

    init_args # No positional args
    def initialize(**kwargs, &block)
      # These aren't being set as styles -- remove them from kwargs before calling super
      # TODO: set [] as default value for items?
      @items = kwargs.delete(:items) || []
      # Nothing is selected unless choose: says so (manual 3234-3237, ledger G3)
      @chosen = kwargs.delete(:choose)

      super(**kwargs)
      @change = block if block

      bind_self_event("change") do |new_item|
        self.chosen = new_item
        @change&.call(self)
      end

      create_display_drawable
    end

    # Select an item. `item` should be a text entry from `items`.
    #
    # @param item [String] the item to choose
    # @return [Shoes::ListBox] self
    def choose(item)
      unless self.items.include?(item)
        raise Shoes::Errors::NoSuchListItemError, "List items (#{self.items.inspect}) do not contain item #{item.inspect}!"
      end

      self.chosen = item
      self
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
      @change = block
      self # Allow chaining calls
    end
  end
end
