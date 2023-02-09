# frozen_string_literal: true

class Scarpe
  class Caption < Para
    def initialize(*args, stroke: nil, **html_attributes)
      super
      @size = :caption
    end
  end
end
