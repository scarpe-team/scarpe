# frozen_string_literal: true

module Shoes
  module Spacing
    def self.included(includer)
      includer.shoes_styles :margin, :padding, :margin_top, :margin_left, :margin_right, :margin_bottom, :options
    end
  end
end
