# frozen_string_literal: true

class Scarpe
  module Hooks
    module Width
      def styles_for_width
        width = @keywords.delete(:width)

        container = {}
        container[:width] = Dimensions.length(width) if width

        { container: }
      end
    end
  end
end
