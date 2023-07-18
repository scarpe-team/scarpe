# frozen_string_literal: true

class Scarpe
  class WebviewArc < Scarpe::WebviewWidget
    def initialize(properties)
      super(properties)
    end

    def element(&block)
      HTML.render do |h|
        h.div(id: html_id, style: style) do
          h.svg(width: @width, height: @height) do
            h.path(d: arc_path)
          end
          block.call(h) if block_given?
        end
      end
    end

    private

    def style
      {
        left: "#{@left}px",
        top: "#{@top}px",
        width: "#{@width}px",
        height: "#{@height}px",
      }
    end

    def arc_path
      center_x = @width / 2
      center_y = @height / 2
      radius_x = @width / 2
      radius_y = @height / 2
      start_angle_degrees = radians_to_degrees(@angle1) % 360
      end_angle_degrees = radians_to_degrees(@angle2) % 360
      large_arc_flag = (end_angle_degrees - start_angle_degrees) % 360 > 180 ? 1 : 0

      "M#{center_x} #{center_y} L#{@width} #{center_y} " \
        "A#{radius_x} #{radius_y} 0 #{large_arc_flag} 0 " \
        "#{center_x + radius_x * Math.cos(degrees_to_radians(end_angle_degrees))} " \
        "#{center_y + radius_y * Math.sin(degrees_to_radians(end_angle_degrees))} Z"
    end

    def degrees_to_radians(degrees)
      degrees * Math::PI / 180
    end

    def radians_to_degrees(radians)
      radians * (180.0 / Math::PI)
    end
  end
end
