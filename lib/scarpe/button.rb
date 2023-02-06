module Scarpe
  class Button
    def initialize(app, text, width:, height:, top:, left:, &block)
      @app = app
      @text = text
      @width = width
      @height = height
      @top = top
      @left = left
      @block = block
      @app.append(render)
    end

    def function_name
      object_id
    end

    def click(&block)
      @block = block
    end

    def render
      @app.bind(function_name) do
        @block.call if @block
      end

      HTML.render do |h|
        h.button(id: function_name, onclick: "scarpeHandler(#{function_name})", style: style) do
          @text
        end
      end
    end

    private

    def style
      styles = {}

      styles[:width] = "#{@width}px" if @width
      styles[:height] = "#{@height}px" if @height

      styles[:top] = "#{@top}px" if @top
      styles[:left] = "#{@left}px" if @left
      styles[:position] = "absolute" if @top || @left

      styles
    end
  end
end
