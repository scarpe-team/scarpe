# frozen_string_literal: true

class Scarpe
  class WebviewOval < Scarpe::WebviewWidget
    def initialize(properties)
      super(properties)
    end

    def element(&block)
      HTML.render do |h|
        h.div(id: html_id, style: style) do
          h.svg(width: @width, height: @height, style: "fill:#{fill_color};") do
            h.ellipse(cx: @width / 2, cy: @height / 2, rx: @width / 2, ry: @height / 2, style: "stroke:#{stroke_color};stroke_width:2")
          end
          block.call(h) if block_given?
        end
      end
    end

    private

    def style
      {
        width: Dimensions.length(@width),
        height: Dimensions.length(@height),
      }
    end

    def fill_color
      ""
    end

    def stroke_color
      "black"
    end
  end
end
