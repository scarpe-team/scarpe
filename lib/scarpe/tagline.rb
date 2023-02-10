# frozen_string_literal: true

class Scarpe
  class Tagline < Para
    def initialize(*args, stroke: nil, **html_attributes)
      super
      @size = :tagline
    end
  end
end
