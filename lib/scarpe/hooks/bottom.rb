# frozen_string_literal: true

class Scarpe
  module Hooks
    module Bottom
      def styles_for_bottom
        bottom = @keywords.delete(:bottom)

        container = {}
        container[:bottom] = Dimensions.length(bottom) if bottom

        { container: }
      end
    end
  end
end
