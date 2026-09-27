# frozen_string_literal: true

class Shoes
  # What a background or a border paints with: a colour, a gradient or an image
  # (manual 785-790, 2754-2755, 2807-2809, ledger D9). Backgrounds, borders and
  # gradients are patterns, and any of them can paint another background or border:
  #
  #   stripe = background tomato
  #   border stripe.to_pattern, strokewidth: 2
  module Pattern
    # The paint inside a pattern, or the value itself when it is already a plain
    # colour or image path.
    def self.paint(value)
      value.is_a?(Pattern) ? value.paint : value
    end

    # @return [Shoes::Pattern] this pattern, to hand to another background or border
    #   (manual 2799-2803, 2854-2858)
    def to_pattern
      self
    end

    # The colour, gradient or image this pattern paints with.
    def paint
      self
    end
  end
end
