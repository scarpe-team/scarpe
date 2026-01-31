# frozen_string_literal: true

module Scarpe::Webview
  class Shape < Drawable
    # Shape is the only (?) remaining drawable that doesn't use Calzini.
    # It's also kind of broken - it doesn't do what a Shoes Shape is
    # supposed to do yet. This can really use a rework at some point.
    def to_html
      @children ||= []
      child_markup = @children.map(&:to_html).join

      color = @draw_context["fill"] || "black"
      self_markup = HTML.render do |h|
        h.div(id: html_id, style: shape_style) do
          h.svg(width: "400", height: "500") do
            h.path(d: path_from_shape_commands, style: "fill:#{color};stroke-width:2;")
          end
        end
      end

      # Put child markup first for backward compatibility, but I'm pretty sure this is wrong.
      child_markup + self_markup
    end

    def element(&block)
      color = @draw_context["fill"] || "black"
      HTML.render do |h|
        h.div(id: html_id, style: shape_style) do
          h.svg(width: "400", height: "500") do
            h.path(d: path_from_shape_commands, style: "fill:#{color};stroke-width:2;")
          end
          block.call(h) if block_given?
        end
      end
    end

    private

    # We have a set of Shoes shape commands, but we need SVG objects like paths.
    def path_from_shape_commands
      current_path = ""

      @shape_commands.each do |cmd, *args|
        case cmd
        when "move_to"
          x, y = *args
          current_path += "M #{x} #{y} "
        when "line_to"
          x, y = *args
          current_path += "L #{x} #{y} "
        when "curve_to"
          cx1, cy1, cx2, cy2, x, y = *args
          current_path += "C #{cx1} #{cy1} #{cx2} #{cy2} #{x} #{y} "
        when "arc_to"
          # Shoes arc_to(cx, cy, w, h, start_angle, end_angle)
          # Convert to SVG arc path. Uses center parameterization → endpoint arc.
          cx, cy, w, h, start_angle, end_angle = *args
          rx = w / 2.0
          ry = h / 2.0
          # Start and end points on the ellipse
          x1 = cx + rx * Math.cos(start_angle)
          y1 = cy - ry * Math.sin(start_angle)
          x2 = cx + rx * Math.cos(end_angle)
          y2 = cy - ry * Math.sin(end_angle)
          # Determine if the arc spans more than 180 degrees
          sweep = (end_angle - start_angle).abs
          large_arc = sweep > Math::PI ? 1 : 0
          # SVG sweep-flag: 0 for counter-clockwise (Shoes convention)
          sweep_flag = end_angle > start_angle ? 0 : 1
          current_path += "M #{x1} #{y1} A #{rx} #{ry} 0 #{large_arc} #{sweep_flag} #{x2} #{y2} "
        else
          raise Scarpe::UnknownShapeCommandError, "Unknown shape command! #{cmd.inspect}"
        end
      end

      current_path
    end

    protected

    def shape_style
      s = {
        width: "400",
        height: "900",
      }
      s[:display] = "none" if @hidden
      s
    end
  end
end
