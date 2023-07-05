# frozen_string_literal: true

class Scarpe
  class Stack < Scarpe::Slot
    include Scarpe::Spacing

    display_properties :width, :height, :margin, :padding, :scroll, :margin_top, :margin_left, :margin_right, :margin_bottom, :options

    def initialize(width: nil, height: "100%", margin: nil, padding: nil, scroll: false, margin_top: nil, margin_bottom: nil, margin_left: nil,
      margin_right: nil, **options, &block)

      # TODO: what are these options? Are they guaranteed serializable?
      @options = options

      super

      create_display_widget
      # Create the display-side widget *before* running the block, which will add child widgets with their display widgets
      Scarpe::App.instance.with_slot(self, &block) if block_given?
    end
  end
end
