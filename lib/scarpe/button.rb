# frozen_string_literal: true

class Scarpe
  class Button < Scarpe::Widget
    def initialize(text, width: nil, height: nil, top: nil, left: nil, &block)
      @text = text
      @width = width
      @height = height
      @top = top
      @left = left
      @block = block

      super

      # Bind to a handler named "click"
      bind_display_event(event_name: "click", target: self.linkable_id) do
        @block&.call
      end

      display_widget_properties(text, width:, height:, top:, left:)
    end

    # Set the click handler
    def click(&block)
      @block = block
    end
  end

  class WebviewButton < WebviewWidget
    def initialize(text, width:, height:, top:, left:, shoes_linkable_id:)
      @text = text
      @width = width
      @height = height
      @top = top
      @left = left

      super

      # Bind to display-side handler for "click"
      bind("click") do
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
