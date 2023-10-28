# frozen_string_literal: true

module Shoes
  class ListBox < Shoes::Drawable
    shoes_styles :selected_item, :items, :height, :width, :choose
    shoes_events :change

    def initialize(args = {}, &block)
      super

      @items = args[:items] || []
      @choose = args[:choose]

      @selected_item = args[:selected_item]

      bind_self_event("change") do |new_item|
        self.selected_item = new_item
        @callback&.call(new_item)
      end

      create_display_drawable
    end

    def change(&block)
      @callback = block
      self # Allow chaining calls
    end
  end
end
