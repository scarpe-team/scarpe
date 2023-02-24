# frozen_string_literal: true

class Scarpe
  module Spacing
    def self.included(includer)
      includer.display_properties :margin, :padding
    end
  end
end
