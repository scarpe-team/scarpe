class Scarpe
    class Flow
      include Scarpe::Container

      attr_reader :app
      def initialize(app, &block)
        @app = app
        @app.append(render)
        append(&block)
      end

      def render
        "<div style='display: flex; flex-direction: row' id=#{object_id}></div>"
      end
    end
  end
