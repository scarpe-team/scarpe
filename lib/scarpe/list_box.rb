# frozen_string_literal: true

class Scarpe
  class ListBox < Scarpe::Widget
    display_properties :selected_item, :items, :height, :width

    def initialize(args = {}, &block)
      @items = args[:items] || []
      @selected_item = args[:selected_item]
      super()

      bind_self_event("change") do |new_item|
        self.selected_item = new_item
        @callback&.call(new_item)
      end

      create_display_widget
    end

    def change(&block)
      @callback = block
    end
  end
end
