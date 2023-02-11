# frozen_string_literal: true

class Scarpe
  module Hooks
    module Left
      def styles_for_left
        left = @keywords.delete(:left)

        container = {}
        container[:left] = Dimensions.length(left) if left
        container[:position] = "absolute" if left

        { container: }
      end
    end
  end
end
