module Scarpe
  class Button
    def initialize(app, text, width:, height:, &block)
      @app = app
      @text = text
      @width = width
      @height = height
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
      "<button id=#{object_id} onclick='scarpeHandler(#{function_name})' style='#{style}'>#{@text}</button>"
    end

    private

    def style
      styles = {}
      styles[:width] = "#{@width}px" if @width
      styles[:height] = "#{@height}px" if @height

      styles.map { |k, v| "#{k}:#{v}" }.join(";")
    end
  end
end
