module Scarpe
  class EditBox
    attr_reader :text, :height, :width

    alias_method :function_name, :object_id

    def initialize(app, text = nil, height: nil, width: nil, &block)
      @app = app
      @text = text || block.call
      @height = height
      @width = width
      @app.append(render)
    end

    def change(&block)
      @callback = block
    end

    def text=(text)
      @text = text
      update_element if @app.window.is_running
    end

    def render
      @app.bind(function_name) do |text|
        @text = text
        @callback&.call(text)
      end

      oninput = "scarpeHandler(#{function_name}, this.value)"

      HTML.render do |h|
        h.textarea(id: object_id, oninput: oninput, style: style) { text }
      end
    end

    private

    def style
      styles = {}

      styles[:height] = Dimensions.length(height)
      styles[:width] = Dimensions.length(width)

      styles.compact
    end

    def update_element
      @app.window.eval("document.getElementById(#{object_id}).value = \"#{text}\";")
    end
  end
end
