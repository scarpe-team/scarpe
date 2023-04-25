# frozen_string_literal: true

class Scarpe
  class Stack < Scarpe::Widget
    include Scarpe::Background
    include Scarpe::Border
    include Scarpe::Spacing
    include Scarpe::Colors

    display_properties :width, :height, :margin, :padding, :scroll, :options

    def initialize(width: nil, height: nil, margin: nil, padding: nil, scroll: false, **options, &block)
      # TODO: what are these options? Are they guaranteed serializable?
      @options = options

      super

      # Create the display-side widget *before* instance_eval, which will add child widgets with their display widgets
      create_display_widget

      instance_eval(&block)
    end
  end
end
