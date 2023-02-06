module Scarpe
  class Dimensions
    def self.length(value)
      case value
      when Integer
        if value < 0
          "calc(100% - #{value.abs}px)"
        else
          "#{value}px"
        end
      when Float
        "#{value*100}%"
      else
        value
      end
    end
  end
end
