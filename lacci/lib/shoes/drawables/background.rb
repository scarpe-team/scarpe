# frozen_string_literal: true

class Shoes
  # A Background drawable represents a colored background layer within a slot.
  # Unlike setting the slot's background_color style directly, a Background
  # drawable can be styled independently (height, width, etc.) and can be
  # shown/hidden/destroyed like any other drawable.
  #
  # In Shoes3, `background blue` returns a Background drawable that can have
  # its style changed later: `@back.style :height => 10`
  class Background < Shoes::Drawable
    shoes_styles :fill, :curve

    shoes_style(:curve) { |val| convert_to_integer(val, "curve") }

    Shoes::Drawable.drawable_default_styles[Shoes::Background][:curve] = 0

    opt_init_args :fill, :curve
    def initialize(*args, **kwargs)
      super
      @draw_context = @app.current_draw_context

      create_display_drawable
    end
  end
end
