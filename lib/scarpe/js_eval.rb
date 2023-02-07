module Scarpe
  class JSEval
    def initialize(app, js_code)
      @app = app
      @js_code = js_code
      @app.append(render)
    end

    def render
      puts "JS code: #{@js_code}" if @app.debug
      @app.do_js_eval(@js_code)
      ""
    end
  end
end
