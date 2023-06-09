# frozen_string_literal: true

class Scarpe
  class WebviewFont < WebviewWidget
    attr_accessor :font

    def initialize(properties)
      super
      @font = properties[:font]
    end

    def element
      puts @font
      HTML.render do |h|
        h.link(href: @file_path, rel: "stylesheet")
        h.style do
          <<~CSS

          @font-face {
            font-family: Pac;
            src: url("#{@file_path}" ) format('truetype');
          }

          html {
            font-family: Pac, Arial, sans-serif;
          }

          CSS
        end

        # Rest of the HTML code for the element
      end
    end
  end
end
