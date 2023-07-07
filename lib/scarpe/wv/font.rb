# frozen_string_literal: true

require "scarpe/base64"

class Scarpe
  class WebviewFont < WebviewWidget
    include Base64
    attr_accessor :font

    def initialize(properties)
      @font = properties[:font]
      super
    end

    def element
      puts @font
      HTML.render do |h|
        h.link(href: @font, rel: "stylesheet")
        h.style do
          <<~CSS
            @font-face {
              font-family: Pacifico;
              src: url("data:font/truetype;base64,#{encode_file_to_base64(@font)}") format('truetype');
            }
            * {
              font-family: Pacifico;
            }
          CSS
        end
      end
    end
  end
end
