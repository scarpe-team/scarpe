# frozen_string_literal: true

module Scarpe::Webview
  class Line < Widget
    def initialize(properties)
      super(properties)
    end

    def element
      ::Scarpe::Components::HTML.render do |h|
        h.div(id: html_id, style: style) do
          h.svg(width: @x2, height: @y2) do
            h.line(x1: @left, y1: @top, x2: @x2, y2: @y2, style: line_style)
          end
        end
      end
    end

    protected

    def style
      super.merge({
        left: "#{@left}px",
        top: "#{@top}px",
      })
    end

    def line_style
      {
        stroke: @draw_context["stroke"],
        "stroke-width": "4",
      }
    end
  end
end
