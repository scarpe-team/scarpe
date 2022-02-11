module Scarpe
  class EditLine
    def initialize(app, &block)
      @app = app
      @block = block
      @text = ""
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
      "<input id=#{object_id} oninput='scarpeHandler(#{function_name}, this.value)' value='#{@text}'></input>"
    end
  end
end