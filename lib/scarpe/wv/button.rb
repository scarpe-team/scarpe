# frozen_string_literal: true

class Scarpe
  class WebviewButton < WebviewWidget
    def initialize(properties)
      super

      # Bind to display-side handler for "click"
      bind("click") do
        # This will be sent to the bind_self_event in Button
        send_self_event(event_name: "click")
      end
    end

    def element
      HTML.render do |h|
        h.button(id: html_id, onclick: handler_js_code("click"), style: style) do
          @text
        end
      end
    end

    private

    def style
      styles = {}
      styles["background-color"] = @color
      styles["padding-top"] = @padding_top
      styles["padding-bottom"] = @padding_bottom
      styles[:color] = @text_color
      styles[:width] = Dimensions.length(@width) if @width
      styles[:height] = Dimensions.length(@height) if @height
      styles["font-size"] = @font_size

      styles[:top] = Dimensions.length(@top) if @top
      styles[:left] = Dimensions.length(@left) if @left
      styles[:position] = "absolute" if @top || @left
      styles["font-size"] = Dimensions.length(font_size) if @size
      styles["font-family"] = @font if @font
      styles["color"] = rgb_to_hex(@stroke) if @stroke
      styles
    end

    def font_size
      font_size = @size.is_a?(Symbol) ? SIZES[@size] : @size

      Dimensions.length(font_size)
    end
  end
end
