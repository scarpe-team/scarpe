# frozen_string_literal: true

class Scarpe
  module Hooks
    module Right
      def styles_for_right
        right = @keywords.delete(:right)

        container = {}
        container[:right] = Dimensions.length(right) if right

        { container: }
      end
    end
  end
end
