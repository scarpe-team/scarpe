# frozen_string_literal: true

module Shoes
  class Progress < Shoes::Widget
    display_properties :fraction

    def initialize(fraction: nil)
      super

      create_display_widget
    end
  end
end
