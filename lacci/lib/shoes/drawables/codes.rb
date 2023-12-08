# frozen_string_literal: true

module Shoes
  class Codes < Shoes::Drawable
    shoes_styles :text

    def initialize(text)
      @text = text
      super

      create_display_drawable
    end
  end
end
