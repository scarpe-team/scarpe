# frozen_string_literal: true

class Scarpe
  class Font < Scarpe::Widget
    display_properties :font

    def initialize(font)
      @font = font
      super

      create_display_widget
    end
  end
end
