module Scarpe
  class Stack
    include Scarpe::Container
    
    attr_reader :app
    def initialize(app, &block)
      @app = app
      @app.append(render)
      append(&block)
    end

    def render
      HTML.render do |h|
        h.div(id: object_id, style: {display: "flex", "flex-direction": "column"})
      end
    end
  end
end
