class Scarpe
  class Em < Scarpe::TextWidget
    def initialize(text)
      @text = text
    end

    def element
      HTML.render do |h|
        h.em { @text }
      end
    end
  end
end
