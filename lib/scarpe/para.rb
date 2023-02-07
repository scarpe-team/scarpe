class Scarpe
  class Para
    def initialize(app, text, stroke: nil, **html_attributes)
      @app = app
      @text = Array(text)
      @stroke = stroke
      @html_attributes = html_attributes
      @app.append(render)
    end

    def render
      HTML.render do |h|
        h.p(**options) do
          render_text
        end
      end
    end

    def render_text
      text
        .map { |t| t.is_a?(Link) ? t.render(self) : t }
        .join
    end

    def replace(new_text)
      app.window.eval("document.getElementById(#{object_id}).innerText = \"#{new_text}\"")
    end

    private

    def options
      html_attributes.merge(id: object_id, style: style)
    end

    def style
      {
        color: stroke
      }.compact
    end

    attr_accessor :text
    attr_reader :app, :stroke, :html_attributes
  end
end
