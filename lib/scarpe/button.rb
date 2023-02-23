# frozen_string_literal: true

class Scarpe
  class Button < Scarpe::Widget
    display_properties :text, :width, :height, :top, :left

    def initialize(text, width: nil, height: nil, top: nil, left: nil, &block)
      # Properties passed as positional args, not keywords, don't get auto-set
      @text = text
      @block = block

      super

      # Bind to a handler named "click"
      bind_self_event("click") do
        @block&.call
      end

      create_display_widget
    end

    # Set the click handler
    def click(&block)
      @block = block
    end
  end

  class WebviewButton < WebviewWidget
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
