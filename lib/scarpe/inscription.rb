# frozen_string_literal: true

class Scarpe
  class Inscription < Para
    alias_as :ins

    def initialize(*args, stroke: nil, **html_attributes)
      super
      @size = :inscription
    end
  end
end
