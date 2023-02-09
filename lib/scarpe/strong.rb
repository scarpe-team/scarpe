# frozen_string_literal: true

class Scarpe
  class Strong < Scarpe::TextWidget
    def initialize(text)
      @text = text
      super
    end

    def element
      HTML.render do |h|
        h.strong { @text }
      end
    end
  end
end
