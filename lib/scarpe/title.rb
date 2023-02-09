# frozen_string_literal: true

class Scarpe
  class Title < Para
    def initialize(*args, stroke: nil, **html_attributes)
      super
      @size = :title
    end
  end
end
