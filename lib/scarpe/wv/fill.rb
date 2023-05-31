# frozen_string_literal: true

class Scarpe
  class WebviewFill < WebviewWidget
    def initialize(properties)
      super(properties)
    end

    def element
      width = @parent.get_style[:width]
      height = @parent.get_style[:height]
      puts "width is #{width}"

      HTML.render do |h|
        h.div(id: html_id, style: style(width, height)) do
          @text
        end
      end
    end

    private

    def style(width, height)
      styles = {}
      styles[:width] = width
      styles[:height] = height
      styles[:background] = @color if @color
      styles
    end
  end
end
