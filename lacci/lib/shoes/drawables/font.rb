# frozen_string_literal: true

module Shoes
  class Font < Shoes::Drawable
    shoes_styles :font

    def initialize(font)
      super
      @font = font

      create_display_drawable
    end
  end
end
