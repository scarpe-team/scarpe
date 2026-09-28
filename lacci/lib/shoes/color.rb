# frozen_string_literal: true

class Shoes
  # A colour, as rgb, gray, the named colours and ask_color give it: four Integers from 0
  # to 255 (manual 643-655, 790-834, ledger D1). It is still an Array, so code that
  # destructures, compares or sends colours keeps working, and displays read it as before.
  class Color < Array
    # @return [Shoes::Color, nil] a colour from [r, g, b(, a)] or a colour string
    def self.from(value)
      case value
      when nil then nil
      when Array then Shoes.rgb(*value)
      else Shoes::Colors.to_rgb(value)
      end
    end

    def red = self[0]
    def green = self[1]
    def blue = self[2]
    def alpha = self[3]
  end
end
