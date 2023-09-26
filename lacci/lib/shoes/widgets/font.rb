# frozen_string_literal: true

module Shoes
  class Font < Shoes::Widget
    display_properties :font

    def initialize(font)
      super
      @font = font

      create_display_widget
    end
  end
end
