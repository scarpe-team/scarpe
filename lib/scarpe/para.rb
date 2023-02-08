class Scarpe
  class Para
    SIZES = {
      inscription: 10,
      ins: 10,
      para: 12,
      caption: 14,
      tagline: 18,
      subtitle: 26,
      title: 34,
      banner: 48
    }.freeze

    def initialize(app, text, stroke: nil, size: :para, **html_attributes)
      @app = app
      @text = Array(text)
      @stroke = stroke
      @size = size
      @html_attributes = html_attributes
      @app.append(render)
    end

    def render
      HTML.render do |h|
        h.p(**options) do
          text.join
        end
      end
    end

    def replace(new_text)
      text = new_text
      app.window.eval("document.getElementById(#{object_id}).innerText = \"#{new_text}\"")
    end

    private

    def options
      html_attributes.merge(id: object_id, style: style)
    end

    def style
      {
        "color" => stroke,
        "font-size" => font_size
      }.compact
    end

    def font_size
      font_size = size.is_a?(Symbol) ? SIZES[size] : size

      Dimensions.length(font_size)
    end

    attr_accessor :text
    attr_reader :app, :size, :stroke, :html_attributes
  end
end
