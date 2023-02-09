# frozen_string_literal: true

class Scarpe
  class Banner < Para
    def initialize(*args, stroke: nil, **html_attributes)
      @size = :banner
      super
    end
  end
end
