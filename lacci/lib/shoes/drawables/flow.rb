# frozen_string_literal: true

module Shoes
  class Flow < Shoes::Slot
    include Shoes::Background
    include Shoes::Border
    include Shoes::Spacing

    display_properties :width, :height, :margin, :padding

    def initialize(width: "100%", height: nil, margin: nil, padding: nil, **options, &block)
      super
      @options = options

      # Create the display-side drawable *before* instance_eval, which will add child drawables with their display drawables
      create_display_drawable

      Shoes::App.instance.with_slot(self, &block) if block_given?
    end
  end
end
