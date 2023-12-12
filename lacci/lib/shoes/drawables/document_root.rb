# frozen_string_literal: true

class Shoes
  class DocumentRoot < Shoes::Flow
    shoes_events # No DocumentRoot-specific events yet

    Shoes::Drawable.drawable_default_styles[Shoes::DocumentRoot][:height] = "100%"
    Shoes::Drawable.drawable_default_styles[Shoes::DocumentRoot][:width] = "100%"

    init_args
    def initialize(**kwargs, &block)
      super
    end

    # The default inspect string can be absolutely huge in console output, and it's frequently printed.
    def inspect
      "<Shoes::DocumentRoot>"
    end
  end
end
