# frozen_string_literal: true

class Scarpe
  class Subtitle < Para
    def initialize(*args, stroke: nil, **html_attributes)
      super
      @size = :subtitle
    end
  end
end
