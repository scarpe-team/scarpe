class Scarpe
  class Link
    InvalidParentError = Class.new(StandardError)

    def initialize(app, text, click: nil, &block)
      @app = app
      @text = text
      @click = click
      @block = block
    end

    def function_name
      object_id
    end

    def click
      @block&.call
    end

    def render(parent)
      raise InvalidParentError unless parent.is_a? Para

      @app.bind(function_name) do
        self&.click
      end

      if @click
        HTML.render do |h|
          h.a(id: function_name, href: @click) { @text }
        end
      else
        HTML.render do |h|
          h.u(id: function_name, onclick: "scarpeHandler(#{function_name})") do
            @text
          end
        end
      end
    end
  end
end
