# frozen_string_literal: true

module Scarpe::Webview
  # Scarpe::Webview::App must only be used from the main thread, due to GTK+ limitations.
  class App < Drawable # App inherits from Drawable to set up linkable IDs and event methods
    attr_reader :control_interface

    attr_writer :shoes_linkable_id

    def initialize(properties)
      super

      # Scarpe's ControlInterface sets up event handlers
      # for the display service that aren't sent to
      # Lacci (Shoes). In general it's used for setup
      # and additional control or testing, outside the
      # Shoes app. This is how CatsCradle and Shoes-Spec
      # set up testing, for instance.
      @control_interface = ControlInterface.new

      # TODO: rename @view
      @view = Scarpe::Webview::WebWrangler.new title: @title,
        width: @width,
        height: @height,
        resizable: @resizable

      @callbacks = {}

      # The control interface has to exist to get callbacks like "override Scarpe app opts".
      # But the Scarpe App needs those options to be created. So we can't pass these to
      # ControlInterface.new.
      @control_interface.set_system_components app: self, doc_root: nil, wrangler: @view

      bind_shoes_event(event_name: "init") { init }
      bind_shoes_event(event_name: "run") { run }
      bind_shoes_event(event_name: "destroy") { destroy }
    end

    attr_writer :document_root

    def init
      scarpe_app = self

      @view.init_code("scarpeInit") do
        request_redraw!
      end

      @view.bind("scarpeHandler") do |*args|
        handle_callback(*args)
      end

      @view.bind("scarpeExit") do
        scarpe_app.destroy
      end
    end

    def run
      # This is run before the Webview event loop is up and running
      @control_interface.dispatch_event(:init)

      @view.empty_page = empty_page_element

      # This takes control of the main thread and never returns. And it *must* be run from
      # the main thread. And it stops any Ruby background threads.
      # That's totally cool and normal, right?
      @view.run
    end

    def destroy
      if @document_root || @view
        @control_interface.dispatch_event :shutdown
      end
      @document_root = nil
      if @view
        @view.destroy
        @view = nil
      end
    end

    # All JS callbacks to Scarpe drawables are dispatched
    # via this handler
    def handle_callback(name, *args)
      if @callbacks.key?(name)
        @callbacks[name].call(*args)
      else
        raise Scarpe::UnknownEventTypeError, "No such Webview callback: #{name.inspect}!"
      end
    end

    # Bind a Scarpe callback name; see handle_callback above.
    # See Scarpe::Drawable for how the naming is set up
    def bind(name, &block)
      @callbacks[name] = block
    end

    # Request a full redraw if Webview is running. Otherwise
    # this is a no-op.
    #
    # @return [void]
    def request_redraw!
      wrangler = DisplayService.instance.wrangler
      if wrangler.is_running
        wrangler.replace(@document_root.to_html)
      end
      nil
    end
  end
end
