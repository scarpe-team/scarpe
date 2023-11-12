# frozen_string_literal: true

class Shoes
  class Video < Shoes::Drawable
    shoes_styles :url
    shoes_events() # No specific events yet

    def initialize(url)
      super
      @url = url
      create_display_drawable
    end

    # other methods
  end
end
