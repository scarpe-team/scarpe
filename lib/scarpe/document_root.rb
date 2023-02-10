# frozen_string_literal: true

class Scarpe
  class DocumentRoot < Scarpe::Widget
    attr_reader :debug
    attr_reader :redraw_requested

    def initialize(webview, opts = {})
      @callbacks = {}
      @opts = opts
      @debug = opts[:debug] ? true : false
      @after_frame_actions = []
      @webview = webview

      Scarpe::Widget.document_root = self
      super
    end

    # Bind a Scarpe callback name; see Scarpe::Widget for how the naming is set up
    def bind(name, &block)
      @callbacks[name] = block
    end

    # All JS callbacks to Scarpe widgets are dispatched
    # via this handler, which is set up in Scarpe::App
    def handle_callback(name, *args)
      @callbacks[name].call(*args)
    end

    # The document root knows when a frame has finished. It registers end-of-frame callbacks and calls them
    # when requested. It also tracks when a redraw has been requested. Note that often frames will be
    # very rare if nothing is changing, with seconds or minutes passing in between them.

    def request_redraw!
      return if @redraw_requested

      @webview.eval("setTimeout(scarpeRedrawCallback,0)")
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

    # This is a bad thing for the document root to know how to do.
    # It is only used for after-frame testing callbacks. This method
    # should be removed when the test infrastructure improves.
    def do_js_eval(js)
      @webview.eval(js + ";")
    end

    # The document root manages the connection between widgets and the WebviewWrangler.
    # By centralising this and wrapping in API functions, we can keep from executing
    # random Javascript, mostly.

    # A Widget can request one or more of these as insertion points in the DOM
    def get_element_wrangler(html_id)
      Scarpe::WebWrangler::ElementWrangler.new(@webview, html_id)
    end
  end
end
