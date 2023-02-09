# frozen_string_literal: true

class Scarpe
  class DocumentRoot < Scarpe::Widget
    attr_reader :window
    attr_reader :debug
    attr_reader :redraw_requested

    def initialize(window, opts = {})
      @callbacks = {}
      @opts = opts
      @debug = opts[:debug] ? true : false
      @after_frame_actions = []

      Scarpe::Widget.window = window
      Scarpe::Widget.document_root = self
      super
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

    def empty
      "<body id='body-#{html_id}' style='border:0;margin:0;'><div id='wrapper-#{html_id}'></div></body>"
    end

    def replace(el)
      @@window.eval("document.getElementById('wrapper-#{html_id}').innerHTML = `#{el}`;")
    end

    def append(el)
      @@window.eval("document.getElementById(#{html_id}).insertAdjacentHTML('beforeend', `#{el}`)")
    end

    def remove(id)
      @@window.eval("document.getElementById(#{id}).remove()")
    end

    def request_redraw!
      return if @redraw_requested

      @@window.eval("setTimeout(scarpeRedrawCallback,0)")
      @redraw_requested = true
    end

    def after_frame(&block)
      @after_frame_actions << block
    end

    def end_of_frame
      @redraw_requested = false
      @after_frame_actions.each { |block| instance_eval(&block) }
    end
    alias_method :info, :puts
  end
end
