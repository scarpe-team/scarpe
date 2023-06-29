# frozen_string_literal: true

class Scarpe
  class Flow < Scarpe::Widget
    include Scarpe::Background
    include Scarpe::Border

    display_properties :width, :height, :margin, :padding

    def initialize(width: nil, height: "100%", margin: nil, padding: nil, &block)
      super

      # Create the display-side widget *before* instance_eval, which will add child widgets with their display widgets
      create_display_widget

      instance_eval(&block)
    end
  end
end
