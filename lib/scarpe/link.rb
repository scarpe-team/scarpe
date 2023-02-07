module Scarpe
  class Link
    def initialize(app, text, &block)
      @app = app
      @text = text
      @block = block
      @app.append(render)
    end

    def function_name
      object_id
    end

    def render
      @app.bind(function_name) do
        @block&.call
      end

      HTML.render do |h|
        h.u(id: function_name, onclick: "scarpeHandler(#{function_name})") do
          @text
        end
      end
    end
  end
end