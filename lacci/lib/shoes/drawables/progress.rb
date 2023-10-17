# frozen_string_literal: true

module Shoes
  class Progress < Shoes::Drawable
    shoes_styles :fraction

    def initialize(fraction: nil)
      super

      create_display_drawable
    end
  end
end
