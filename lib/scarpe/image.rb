module Scarpe
  class Image
    def initialize(app, url)
      @app = app
      @url = url
      @app.append(render)
    end

    def render
      "<img id=#{object_id} src=\"#{@url}\">"
    end
  end
end