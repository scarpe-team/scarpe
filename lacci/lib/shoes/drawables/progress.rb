# frozen_string_literal: true

class Shoes
  class Progress < Shoes::Drawable
    shoes_styles :fraction
    shoes_events # No Progress-specific events yet

    def initialize(fraction: nil)
      super

      create_display_drawable
    end
  end
end
