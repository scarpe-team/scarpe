# frozen_string_literal: true

module Shoes
  class Flow < Shoes::Slot
    display_properties :width, :height, :margin, :padding

    def initialize(width: "100%", height: nil, margin: nil, padding: nil, **options, &block)
      @options = options

      super

      # Create the display-side widget *before* instance_eval, which will add child widgets with their display widgets
      create_display_widget

      Shoes::App.instance.with_slot(self, &block) if block_given?
    end
  end
end
