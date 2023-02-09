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

      # Bind to a handler named "click"
      bind("click") do
        @block&.call
      end

      super
    end

    def click(&block)
      @block = block
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
