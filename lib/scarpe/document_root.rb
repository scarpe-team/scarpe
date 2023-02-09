class Scarpe
  class DocumentRoot < Scarpe::Widget
    attr_reader :window
    attr_reader :debug
    attr_reader :children

    def initialize(window, opts = {})
      @callbacks = {}
      @opts = opts
      @debug = opts[:debug] ? true : false
      @after_frame_actions = []
      @changed = false

      Scarpe::Widget.set_window(window)
      Scarpe::Widget.set_document_root(self)
    end

    def changed!
      @changed || @changed = true
    end

    def bind(name, &block)
      @callbacks[name] = block
    end

    def handle_callback(name, *args)
      @callbacks[name].call(*args)
    end

    def do_js_eval(js)
      @@window.eval(js + ";")
    end

    def after_frame(&block)
      @after_frame_actions << block
    end

    def render
      @@window.eval("document.getElementById(#{html_id}).innerHTML = `#{to_html}`")
      @changed = false
    end

    def end_of_frame
      render if should_render?
      @after_frame_actions.each { |block| instance_eval(&block) }
    end

    private

    def should_render?
      @changed
    end
  end
end
