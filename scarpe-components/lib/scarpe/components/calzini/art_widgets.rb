# frozen_string_literal: true

module Scarpe::Components::Calzini
  def arc_element(props, &block)
    HTML.render do |h|
      h.div(id: html_id, style: arc_style(props)) do
        h.svg(width: props["width"], height: props["height"]) do
          h.path(d: arc_path(props))
        end
        block.call(h) if block_given?
      end
    end
  end

  def line_element(props)
    HTML.render do |h|
      h.div(id: html_id, style: line_div_style(props)) do
        h.svg(width: props["x2"], height: props["y2"]) do
          h.line(x1: props["left"], y1: props["top"], x2: props["x2"], y2: props["y2"], style: line_svg_style(props))
        end
      end
    end
  end

  def star_element(props, &block)
    dc = props["draw_context"] || {}
    fill = dc["fill"]
    stroke = dc["stroke"]
    fill = "black" if !fill || fill == ""
    stroke = "black" if !stroke || stroke == ""
    HTML.render do |h|
      h.div(id: html_id, style: star_style(props)) do
        h.svg(width: props["outer"], height: props["outer"], style: "fill:#{fill}") do
          h.polygon(points: star_points(props), style: "stroke:#{stroke};stroke-width:2")
        end
        block.call(h) if block_given?
      end
    end
  end

  private

  def arc_style(props)
    widget_style(props).merge({
      left: "#{props["left"]}px",
      top: "#{props["top"]}px",
      width: "#{props["width"]}px",
      height: "#{props["height"]}px",
    })
  end

  def arc_path(props)
    center_x = props["width"] / 2
    center_y = props["height"] / 2
    radius_x = props["width"] / 2
    radius_y = props["height"] / 2
    start_angle_degrees = radians_to_degrees(props["angle1"]) % 360
    end_angle_degrees = radians_to_degrees(props["angle2"]) % 360
    large_arc_flag = (end_angle_degrees - start_angle_degrees) % 360 > 180 ? 1 : 0

    "M#{center_x} #{center_y} L#{props["width"]} #{center_y} " \
      "A#{radius_x} #{radius_y} 0 #{large_arc_flag} 0 " \
      "#{center_x + radius_x * Math.cos(degrees_to_radians(end_angle_degrees))} " \
      "#{center_y + radius_y * Math.sin(degrees_to_radians(end_angle_degrees))} Z"
  end

  def line_div_style(props)
    widget_style(props).merge({
      left: "#{props["left"]}px",
      top: "#{props["top"]}px",
    })
  end

  def line_svg_style(props)
    {
      stroke: (props["draw_context"] || {})["stroke"],
      "stroke-width": "4",
    }.compact
  end

  def star_style(props)
    widget_style(props).merge({
      width: dimensions_length(props["width"]),
      height: dimensions_length(props["height"]),
    }).compact
  end

  def star_points(props)
    angle = 2 * Math::PI / props["points"]
    coordinates = []

    props["points"].times do |i|
      outer_angle = i * angle
      inner_angle = outer_angle + angle / 2

      coordinates.concat(star_get_coordinates(outer_angle, inner_angle, props))
    end

    coordinates.join(",")
  end

  def star_get_coordinates(outer_angle, inner_angle, props)
    outer_x = props["outer"] / 2 + Math.cos(outer_angle) * props["outer"] / 2
    outer_y = props["outer"] / 2 + Math.sin(outer_angle) * props["outer"] / 2

    inner_x = props["outer"] / 2 + Math.cos(inner_angle) * props["inner"] / 2
    inner_y = props["outer"] / 2 + Math.sin(inner_angle) * props["inner"] / 2

    [outer_x, outer_y, inner_x, inner_y]
  end
end
