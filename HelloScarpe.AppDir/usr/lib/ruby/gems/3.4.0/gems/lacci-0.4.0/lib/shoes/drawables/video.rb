# frozen_string_literal: true

class Shoes
  class Video < Shoes::Drawable
    shoes_styles :url
    shoes_events # No specific events yet

    init_args :url
    def initialize(*args, **kwargs)
      super

      create_display_drawable
    end

    # other methods
  end
end
