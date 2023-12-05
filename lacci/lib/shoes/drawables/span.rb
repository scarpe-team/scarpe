# frozen_string_literal: true

class Shoes
  class Span < Shoes::Drawable
    shoes_styles :text, :stroke, :size, :font, :html_attributes
    shoes_events # No Span-specific events yet

    Shoes::Drawable.drawable_default_styles[Shoes::Span][:size] = :span

    init_args
    opt_init_args :text, :stroke, :size, :font
    def initialize(*args, **html_attributes)
      super

      @html_attributes = html_attributes

      create_display_drawable
    end

    def replace(text)
      @text = text

      # This should signal the display drawable to change
      self.text = @text
    end
  end
end
