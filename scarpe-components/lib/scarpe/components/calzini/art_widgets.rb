# frozen_string_literal: true

module Scarpe::Components::Calzini
  def arc_element(props, &block)
    dc = props["draw_context"] || {}
    rotate = dc["rotate"]
    HTML.render do |h|
      h.div(id: html_id, style: arc_style(props)) do
        h.svg(width: props["width"], height: props["height"]) do
          h.path(d: arc_path(props), transform: "rotate(#{rotate}, #{props["width"] / 2}, #{props["height"] / 2})")
        end
        block.call(h) if block_given?
      end
    end
  end

  def rect_element(props)
    dc = props["draw_context"] || {}
    rotate = dc["rotate"]
    HTML.render do |h|
      h.div(id: html_id, style: drawable_style(props)) do
        width = props["width"].to_i
        height = props["height"].to_i
        if props["curve"]
          width += 2 * props["curve"].to_i
          height += 2 * props["curve"].to_i
        end
        h.svg(width:, height:) do
          attrs = { x: props["left"], y: props["top"], width: props["width"], height: props["height"], style: rect_svg_style(props) }
          attrs[:rx] = props["curve"] if props["curve"]

          h.rect(**attrs, transform: "rotate(#{rotate} #{width / 2} #{height / 2})")
        end
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
    drawable_style(props).merge({
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
    drawable_style(props).merge({
      left: "#{props["left"]}px",
      top: "#{props["top"]}px",
    })
  end

  def line_svg_style(props)
    stroke = if props["draw_context"] && !props["draw_context"]["stroke"].to_s.empty?
      (props["draw_context"]["stroke"]).to_s
    else
      "black"
    end
    {

      "stroke": stroke,
      "stroke-width": "4",
    }.compact
  end

  def rect_svg_style(props)
    {
      stroke: (props["draw_context"] || {})["stroke"],
      #"stroke-width": "1",
    }.compact
  end

  def star_style(props)
    drawable_style(props).merge({
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

  def arrow_element(props)
    left = props["left"]
    top = props["top"]
    width = props["width"]
    end_x = left + width
    end_y = top
    stroke_width = width / 2
    dc = props["draw_context"] || {}
    fill = dc["fill"]
    stroke = dc["stroke"]
    rotate = dc["rotate"]
    fill = "black" if !fill || fill == ""
    stroke = "black" if !stroke || stroke == ""

    stroke_width = width / 4

    HTML.render do |h|
      h.div(id: html_id, style: arrow_div_style(props)) do
        h.svg do
          h.defs do
            h.marker(
              id: "head",
              viewBox: "0 0 70 70",
              markerWidth: stroke_width.to_s,
              markerHeight: stroke_width.to_s,
              refX: "5",
              refY: "5",
              orient: "auto-start-reverse",
            ) do
              h.path(d: "M 0 0 L 10 5 L 0 10 z", fill: fill.to_s)
            end
          end

          h.line(
            x2: left.to_s,
            y2: top.to_s,
            x1: end_x.to_s,
            y1: end_y.to_s,
            fill: fill.to_s,
            stroke: stroke.to_s,
            "stroke-width" => stroke_width.to_s,
            "marker-end" => "url(#head)",
            transform: "rotate(#{rotate}, #{left + width / 2}, #{top})",
          )
        end
      end
    end
  end
  def arrow_div_style(props)
    drawable_style(props).merge({
      position: "absolute",
      left: "#{props["left"]}px",
      top: "#{props["top"]}px",
    })
  end
end
