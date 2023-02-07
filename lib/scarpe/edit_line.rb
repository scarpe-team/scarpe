module Scarpe
  class EditLine
    def initialize(app, text = "", width: nil, &block)
      @app = app
      @block = block
      @text = text
      @width = width
      @app.append(render)
    end

    def function_name
      object_id
    end

    def change(&block)
      @block = block
    end

    def text
      @text
    end

    def text=(text)
      @text = text
      if @app.window.is_running
        @app.window.eval("document.getElementById(#{object_id}).value = \"#{@text}\";")
      end
    end

    def render
      @app.bind(function_name) do |text|
        @text = text
        if @block
          @block.call(text)
        end
      end

      oninput = "scarpeHandler(#{function_name}, this.value)"

      HTML.render do |h|
        h.input(id: object_id, oninput: oninput, value: @text, style: style)
      end
    end

    private

    def style
      styles = {}

      styles[:width] = ::Scarpe::Dimensions.length(@width) if @width

      styles
    end
  end
end
