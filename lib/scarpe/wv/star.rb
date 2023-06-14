# frozen_string_literal: true

class Scarpe
  class WebviewStar < Scarpe::WebviewWidget
    def initialize(properties)
      super(properties)
    end

    def element(&block)
      HTML.render do |h|
        h.div(id: html_id, style: style) do
          h.svg(width: @outer, height: @outer, style: "fill:#{fill_color};") do
            h.polygon(points: star_points, style: "stroke:#{stroke_color};stroke-width:2")
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

    def star_points
      get_star_points.join(",")
    end

    def get_star_points
      angle = 2 * Math::PI / @points
      coordinates = []

      @points.times do |i|
        outer_angle = i * angle
        inner_angle = outer_angle + angle / 2

        coordinates.concat(get_coordinates(outer_angle, inner_angle))
      end

      coordinates
    end

    def get_coordinates(outer_angle, inner_angle)
      outer_x = @outer / 2 + Math.cos(outer_angle) * @outer / 2
      outer_y = @outer / 2 + Math.sin(outer_angle) * @outer / 2

      inner_x = @outer / 2 + Math.cos(inner_angle) * @inner / 2
      inner_y = @outer / 2 + Math.sin(inner_angle) * @inner / 2

      [outer_x, outer_y, inner_x, inner_y]
    end

    def fill_color
      ""
    end

    def stroke_color
      "black"
    end
  end
end
