module Scarpe
  class Alert
    def initialize(app, text)
      @app = app
      @text = text
      @app.append(render)
    end

    def function_name
      object_id
    end

    def render
      @app.bind(function_name) do
        @app.remove(object_id)
      end

      onclick = "scarpeHandler(#{function_name})"

      HTML.render do |h|
        h.div(id: object_id, style: overlay_style) do
          h.div(style: modal_style) do
            h.div(style: text_style) { @text }
            h.button(style: button_style, onclick: onclick) { "OK" }
          end
        end
      end
    end

    private

    def overlay_style
      {
        position: "fixed",
        top: "0",
        left: "0",
        width: "100%",
        height: "100%",
        overflow: "auto",
        "z-index": "1",
        background: "rgba(0,0,0,0.4)",
        display: "flex",
        "align-items": "center",
        "justify-content": "center"
      }
    end

    def modal_style
      {
        "min-width": "200px",
        "min-height": "50px",
        padding: "10px",
        display: "flex",
        background: "#fefefe",
        "flex-direction": "column",
        "justify-content": "space-between",
        "border-radius": "9px"
      }
    end

    def text_style
      {}
    end

    def button_style
      {}
    end
  end
end
