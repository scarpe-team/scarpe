# frozen_string_literal: true

class Scarpe
  class WebviewDocumentRoot < Scarpe::WebviewWidget
    include Scarpe::WebviewBackground

    attr_reader :debug
    attr_reader :redraw_requested

    def initialize(properties)
      @callbacks = {}

      super
    end

    def element(&blck)
      HTML.render do |h|
        h.div(style:, &blck)
      end
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

      wrangler = WebviewDisplayService.instance.wrangler
      if wrangler.is_running
        wrangler.js_eval("setTimeout(scarpeRedrawCallback,0)")
      end
      @redraw_requested = true
    end

    def end_of_frame
      @redraw_requested = false
    end

    # The document root manages the connection between widgets and the WebviewWrangler.
    # By centralising this and wrapping in API functions, we can keep from executing
    # random Javascript, mostly.

    # A Widget can request one or more of these as insertion points in the DOM
    def get_element_wrangler(html_id)
      Scarpe::WebWrangler::ElementWrangler.new(html_id)
    end
  end
end
