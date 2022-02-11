module Scarpe
  class Button
    def initialize(app, text, &block)
      @app = app
      @text = text
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
        if @block
          @block.call
        end
      end
      "<button id=#{object_id} onclick='scarpeHandler(#{function_name})'>#{@text}</button>"
    end
  end
end