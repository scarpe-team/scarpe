class Scarpe
  class DocumentRoot < Scarpe::Widget
    attr_reader :window
    attr_reader :debug

    def initialize(window, opts = {})
      @callbacks = {}
      @opts = opts
      @debug = opts[:debug] ? true : false
      @after_frame_actions = []

      Scarpe::Widget.set_window(window)
      Scarpe::Widget.set_document_root(self)
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

    def append(el)
      @@window.eval("document.getElementById(#{html_id}).insertAdjacentHTML('beforeend', \`#{el}\`)")
    end

    def remove(id)
      @@window.eval("document.getElementById(#{id}).remove()")
    end

    def after_frame(&block)
      @after_frame_actions << block
    end

    def end_of_frame
      @after_frame_actions.each { |block| instance_eval(&block) }
    end
  end
end
