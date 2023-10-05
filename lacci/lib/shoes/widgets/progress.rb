# frozen_string_literal: true

module Shoes
  class Progress < Shoes::Widget
    def initialize(*args)
      super

      create_display_widget
    end
  end
end
