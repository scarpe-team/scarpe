# frozen_string_literal: true

class Scarpe
  class Em < Scarpe::TextWidget
    def initialize(text)
      @text = text
      super
    end

    def element
      HTML.render do |h|
        h.em { @text }
      end
    end
  end
end
