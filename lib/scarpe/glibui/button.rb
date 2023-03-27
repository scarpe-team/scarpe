# frozen_string_literal: true

class Scarpe
  class GlimmerLibUIButton < GlimmerLibUIWidget
    def initialize(properties)
      super

      # Bind to display-side handler for "click"
      bind("click") do
        # This will be sent to the bind_self_event in Button
        send_display_event(event_name: "click", target: shoes_linkable_id)
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

      styles[:width] = Dimensions.length(@width) if @width
      styles[:height] = Dimensions.length(@height) if @height

      styles[:top] = Dimensions.length(@top) if @top
      styles[:left] = Dimensions.length(@left) if @left
      styles[:position] = "absolute" if @top || @left

      styles
    end
  end
end
