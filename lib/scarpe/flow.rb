# frozen_string_literal: true

class Scarpe
  class Flow < Scarpe::Slot
    display_properties :width, :height, :margin, :padding

    def initialize(width: nil, height: nil, margin: nil, padding: nil, **options, &block)
      @options = options

      super

      # Create the display-side widget *before* instance_eval, which will add child widgets with their display widgets
      create_display_widget

      Scarpe::App.instance.with_slot(self, &block) if block_given?
    end
  end
end
