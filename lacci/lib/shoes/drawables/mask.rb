# frozen_string_literal: true

# In Shoes3, `mask` creates a slot whose shapes define a clipping mask
# for the parent slot. The content drawn inside the mask block determines
# which areas of the parent's other content are visible.
#
# Example:
#   stack do
#     background red
#     mask do
#       star 100, 100, 10, 100, 50
#     end
#   end
#
# This would show the red background only through the star shape.
class Shoes
  class Mask < Shoes::Slot
    shoes_events

    def initialize(*args, **kwargs, &block)
      super

      create_display_drawable

      @app.with_slot(self, &block) if block_given?
    end
  end
end
