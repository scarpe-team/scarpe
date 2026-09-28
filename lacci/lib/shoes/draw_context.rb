# frozen_string_literal: true

class Shoes
  # The pen shapes are drawn with: fill, stroke, strokewidth, rotation, scale, skew,
  # transform origin, translation and line caps (manual 1676-1868). A setting made
  # here holds for the shapes drawn afterwards in this slot and its children, which
  # inherit whatever they do not set themselves.
  #
  # Slots have one, and so does image(w, h) { }, which is drawn on like a slot.
  module DrawContext
    SETTINGS = %w[fill stroke strokewidth rotate scale skew transform translate cap].freeze

    # This only shows this slot's own settings, not its parent's.
    # Use current_draw_context to allow inheritance.
    def draw_context
      @draw_context ||= SETTINGS.to_h { |setting| [setting, nil] }
    end

    # Set the default fill color in this slot and child slots.
    # Pass nil for "no setting", so that it can inherit defaults.
    #
    # @param color [Nil,Color] a Shoes color for the fill color or nil to use parent setting
    # @return [Color, nil] the pattern, as the manual's fill(pattern) » pattern
    def fill(color)
      draw_context["fill"] = Shoes::Pattern.paint(color)
    end

    # Set the default fill in this slot and child slots to transparent.
    #
    # @return [self]
    def nofill
      draw_context["fill"] = rgb(0, 0, 0, 0)
      self
    end

    # Set the default stroke color in this slot and child slots.
    # Pass nil for "no setting" so it can inherit defaults.
    #
    # @param color [Nil,Color] a Shoes color for the stroke color or nil to use parent setting
    # @return [Color, nil] the pattern, as the manual's stroke(pattern) » pattern
    def stroke(color)
      draw_context["stroke"] = Shoes::Pattern.paint(color)
    end

    # Set the default strokewidth in this slot and child slots.
    # Pass nil for "no setting".
    #
    # @param width [Numeric,Nil] the new width, or nil to use parent setting
    # @return [self]
    def strokewidth(width)
      draw_context["strokewidth"] = width
      self
    end

    # Set the default stroke in this slot and child slots
    # to transparent.
    #
    # @return [self]
    def nostroke
      draw_context["stroke"] = rgb(0, 0, 0, 0)
      self
    end

    # Turn the pen by `angle` degrees more (manual 1783-1797). Turns add up, as they do
    # on Shoes 3's canvas matrix (ledger E10), so rotate 1 in every frame of an animate
    # spins what it draws. The draw context carries the running total.
    # Pass nil to drop this slot's own turn and use its parent's.
    #
    # @param angle [Numeric,Nil] degrees to turn by, or nil to use the parent setting
    # @return [self]
    def rotate(angle)
      draw_context["rotate"] = angle && (current_draw_context["rotate"] || 0) + angle
      self
    end

    # Move the pen: a shape drawn at (50, 60) after translate(10, 20) lands at (60, 80)
    # (manual 1862-1868). Moves add up, as they do on Shoes 3's canvas matrix, so the
    # draw context carries the running total.
    #
    # @return [self]
    def translate(left, top)
      x, y = current_draw_context["translate"] || [0, 0]
      draw_context["translate"] = [x + left, y + top]
      self
    end

    # Turn, scale and skew shapes about their :center or their :corner, the default
    # (manual 1857-1860).
    #
    # @param origin [Symbol] :center or :corner
    # @return [self]
    def transform(origin)
      draw_context["transform"] = origin
      self
    end

    # The shape of line ends: :rect (flat, the default), :curve (round) or :project
    # (square, sticking out) (manual 1676-1680).
    #
    # @return [self]
    def cap(style)
      draw_context["cap"] = style
      self
    end

    # Set the current scale factor in this slot and any child slots.
    # Pass nil to reset scale to default.
    #
    # @param x [Numeric,Range,Nil] the x scale factor (or uniform scale), or a Range to pick a random value
    # @param y [Numeric,Nil] the y scale factor (optional, defaults to x)
    # @return [self]
    def scale(x, y = nil)
      # Handle Range (Shoes3 allows scale((0.8..1.2).rand) or scale(0.8..1.2))
      x = x.rand if x.is_a?(Range)
      y = y.rand if y.is_a?(Range)
      y ||= x
      draw_context["scale"] = [x, y]
      self
    end

    # Set the current skew transform in this slot and any child slots.
    # Pass nil to reset skew to default.
    #
    # @param x [Numeric,Nil] the x skew angle (in degrees or radians depending on Shoes3 behavior)
    # @param y [Numeric,Nil] the y skew angle (optional, defaults to 0)
    # @return [self]
    def skew(x, y = nil)
      y ||= 0
      draw_context["skew"] = [x, y]
      self
    end

    # Get the current draw context styles, based on this slot and its parent slots.
    #
    # @return [Hash] a hash of Shoes styles for the context
    def current_draw_context
      s = @parent ? @parent.current_draw_context : {}
      draw_context.each { |k, v| s[k] = v unless v.nil? }

      s
    end
  end
end
