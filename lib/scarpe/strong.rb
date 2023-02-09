class Scarpe
  class Strong < Scarpe::TextWidget
    def initialize(text)
      @text = text
    end

    def element
      HTML.render do |h|
        h.strong { @text }
      end
    end
  end
end
