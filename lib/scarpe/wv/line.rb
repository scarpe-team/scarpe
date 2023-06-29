# frozen_string_literal: true

require_relative "shape_helper"
class Scarpe
  class WebviewLine < Scarpe::WebviewWidget
    include ShapeHelper

    def initialize(properties)
      super(properties)
      puts "x2: #{@x2}"
    end

    def element
      HTML.render do |h|
        h.div(id: html_id, style: style) do
          h.svg(width: @x2, height: @y2) do
            h.line(x1: @left, y1: @top, x2: @x2, y2: @y2, style: line_style)
          end
        end
      end
    end

    private

    def style
      {
        left: "#{@left}px",
        top: "#{@top}px",
      }
    end

    def line_style
      {
        stroke: "#{color_for_fill}",
        "stroke-width": "4",
      }
    end
  end
end
