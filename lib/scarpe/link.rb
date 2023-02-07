class Scarpe
  class Link
    def initialize(app, text, &block)
      @app = app
      @text = text
      @block = block
    end

    def function_name
      object_idg
    end

    def render(parent)
      raise "Links must be rendered with a para" unless parent.is_a? Para

      @app.bind(function_name) do
        @block&.call
      end

      html = HTML.render do |h|
        h.u(id: function_name, onclick: "scarpeHandler(#{function_name})") do
          @text
        end
      end
    end
  end
end
