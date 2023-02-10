# frozen_string_literal: true

class Scarpe
  class Banner < Para
    def initialize(*args, stroke: nil, **html_attributes)
      super
      @size = :banner
    end
  end
end
