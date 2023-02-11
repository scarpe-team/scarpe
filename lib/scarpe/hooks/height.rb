# frozen_string_literal: true

class Scarpe
  module Hooks
    module Height
      def styles_for_height
        height = @keywords.delete(:height)

        container = {}
        container[:height] = Dimensions.length(height) if height

        { container: }
      end
    end
  end
end
