# frozen_string_literal: true

class Scarpe
  module Hooks
    module Top
      def styles_for_top
        top = @keywords.delete(:top)

        container = {}
        container[:top] = Dimensions.length(top) if top
        container[:position] = "absolute" if top

        { container: }
      end
    end
  end
end
