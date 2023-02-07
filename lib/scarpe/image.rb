module Scarpe
  class Image
    def initialize(app, url)
      @app = app
      @url = url
      @app.append(render)
    end

    def render
      HTML.render do |h|
        h.img(id: object_id, src: @url)
      end
    end
  end
end
