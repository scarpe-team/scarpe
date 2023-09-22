# frozen_string_literal: true

module Scarpe::Webview
  class Shape < Widget

    def initialize(properties)
      super(properties)
    end

    def to_html
      @children ||= []
      child_markup = @children.map(&:to_html).join

      color = @draw_context["fill"] || "black"
      self_markup = ::Scarpe::Components::HTML.render do |h|
        h.div(id: html_id, style: style) do
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
      ::Scarpe::Components::HTML.render do |h|
        h.div(id: html_id, style: style) do
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
        else
          raise Scarpe::UnknownShapeCommandError, "Unknown shape command! #{cmd.inspect}"
        end
      end

      current_path
    end

    protected

    def style
      super.merge({
        width: "400",
        height: "900",
      })
    end
  end
end
