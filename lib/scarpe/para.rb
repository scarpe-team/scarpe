module Scarpe
  class Para
    def initialize(app, text)
      @app = app
      @text = text
      @app.append(render)
    end

    def render
      "<p id=#{object_id}>#{@text}</p>"
    end

    def replace(text)
      @text = text
      @app.window.eval("document.getElementById(#{object_id}).innerText = \"#{text}\"")
    end
  end
end