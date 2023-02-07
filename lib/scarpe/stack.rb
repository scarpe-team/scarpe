module Scarpe
  class Stack
    include Scarpe::Container
    
    attr_reader :app
    def initialize(app, margin:, &block)
      @app = app
      @margin = margin
      @app.append(render)
      append(&block)
    end

    def render
      HTML.render do |h|
        h.div(id: object_id, style: style)
      end
    end

    private

    def style
      styles = {}

      styles[:display] = "flex"
      styles["flex-direction"] = "column"
      styles[:margin] = Dimensions.length(@margin) if @margin

      styles
    end
  end
end
