# frozen_string_literal: true

class Scarpe
  class Stack < Scarpe::Slot
    # TODO: sort out various margin and padding properties, including putting stuff into spacing
    display_properties :width, :height, :scroll

    def initialize(width: nil, height: nil, margin: nil, padding: nil, scroll: false, margin_top: nil, margin_bottom: nil, margin_left: nil,
      margin_right: nil, **options, &block)

      @options = options

      super

      create_display_widget
      # Create the display-side widget *before* running the block, which will add child widgets with their display widgets
      Scarpe::App.instance.with_slot(self, &block) if block_given?
    end
  end
end
