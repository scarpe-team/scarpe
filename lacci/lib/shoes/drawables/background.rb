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
    include Shoes::Pattern

    uses_draw_context
    shoes_style(:fill) { |paint| Shoes::Pattern.paint(paint) } # another pattern paints this one too
    shoes_styles :curve, :angle

    shoes_style(:curve) { |val| convert_to_integer(val, "curve") }

    Shoes::Drawable.drawable_default_styles[Shoes::Background][:curve] = 0

    opt_init_args :fill, :curve
    def initialize(*args, **kwargs)
      super
      @draw_context = @app.current_draw_context
      # angle: turns the gradient (manual 1073-1079, ledger D6). It travels inside the
      # fill, where displays already read a gradient's angle.
      @fill = turned(@fill, @angle) if @angle

      create_display_drawable
    end

    # @return [Object] the colour, gradient or image this background paints
    def paint
      @fill
    end

    private

    def turned(fill, angle)
      case fill
      when Range then gradient(fill.begin, fill.end, angle:)
      when Shoes::Colors::Gradient then Shoes::Colors::Gradient.new(fill.color1, fill.color2, angle)
      else fill
      end
    end
  end
end
