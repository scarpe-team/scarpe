# frozen_string_literal: true

class Shoes
  class Link < Shoes::TextDrawable
    shoes_styles :text, :click, :has_block
    shoes_events :click

    #Shoes::Drawable.drawable_default_styles[Shoes::Link][:click] = "#"

    init_args # Empty by the time it reaches Drawable#initialize
    def initialize(*args, **kwargs, &block)
      @block = block

      # Check if click is an internal route (starts with /)
      click_value = kwargs[:click]
      @internal_route = click_value.is_a?(String) && click_value.start_with?("/")

      # We can't send a block to the display drawable, but we can send a boolean
      # Also set has_block if we have an internal route (so display uses onclick, not href)
      @has_block = !block.nil? || @internal_route

      super

      bind_self_event("click") do
        if @internal_route
          # Navigate to the internal route
          app.visit(@click)
        end
        @block&.call
      end
    end
  end

  # In Shoes, the LinkHover pseudo-class is used to set default styles for links when
  # hovered over. The functionality isn't present in Lacci yet.
  class LinkHover < Link
    def initialize
      raise "This class should never be instantiated directly! Use link, not link_hover!"
    end
  end
end
