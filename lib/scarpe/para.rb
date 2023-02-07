module Scarpe
  class Para
    def initialize(app, text)
      @app = app
      @text = Array(text)
      @app.append(render)
    end

    def render
      "<p id=#{object_id}>#{text.join}</p>"
    end

    def replace(new_text)
      text = new_text
      app.window.eval("document.getElementById(#{object_id}).innerText = \"#{new_text}\"")
    end

    private

    attr_accessor :text
    attr_reader :app
  end
end
