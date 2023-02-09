# frozen_string_literal: true

class Scarpe
  class Code < Scarpe::TextWidget
    def initialize(text)
      @text = text
      super
    end

    def element
      HTML.render do |h|
        h.code { @text }
      end
    end
  end
end
