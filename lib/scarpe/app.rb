# frozen_string_literal: true

require_relative "control_interface"
require_relative "web_wrangler"

class Scarpe
  # Scarpe::App must only be used from the main thread, due to GTK+ limitations.
  class App
    # TODO: Do something with resizable in the future.
    # For now, we accept it as a valid option so it doesn't crash examples.
    VALID_OPTS = [
      :debug,           # print out debug statements
      :resizable,       # the app is resizable (currently ignored)
      :no_control,      # do not run a test-control file, even if one is specified in SCARPE_TEST_CONTROL
    ]

    attr_reader :do_debug
    attr_reader :control_interface

    def initialize(title: "Scarpe!", width: 480, height: 420, **opts, &app_code_body)
      bad_opts = opts.keys - VALID_OPTS
      raise "Illegal options to Scarpe::App.initialize! #{bad_opts.inspect}" unless bad_opts.empty?

      # It's possible to provide a Ruby script by setting
      # SCARPE_TEST_CONTROL to its file path. This can
      # allow pre-setting test options or otherwise
      # performing additional actions not written into
      # the Shoes app itself.
      #
      # The control interface is what lets these files see
      # events, specify overrides and so on.
      @control_interface = ControlInterface.new
      if ENV["SCARPE_TEST_CONTROL"] && !opts[:no_control]
        @control_interface.instance_eval File.read(ENV["SCARPE_TEST_CONTROL"])
      end

      opts = @control_interface.app_opts_get_override(opts)

      @title = title
      @width = width
      @height = height

      @do_debug = opts[:debug] ? true : false
      @view = Scarpe::WebWrangler.new title: title, width: width, height: height, debug: do_debug
      @document_root = Scarpe::DocumentRoot.new(@view, { debug: do_debug })

      # The control interface has to exist to get callbacks like "override Scarpe app opts".
      # But the Scarpe App needs those options to be created. So we can't pass these to
      # ControlInterface.new.
      @control_interface.set_system_components app: self, doc_root: @document_root, wrangler: @view

      @opts = opts
      @app_code_body = app_code_body
    end

    def init
      scarpe_app = self

      @view.init_code("scarpeInit") do
        @document_root.instance_eval(&@app_code_body)
        redraw_frame
      end

      @view.bind("scarpeHandler") do |*args|
        @document_root.handle_callback(*args)
      end

      @view.bind("scarpeExit") do
        scarpe_app.destroy
      end

      @view.bind("scarpeRedrawCallback") do
        puts("Redraw!") if do_debug
        redraw_frame if @document_root.redraw_requested
      end

      @control_interface.dispatch_event(:init)
    end

    # Draw a frame, call the per-frame callback(s)
    def redraw_frame
      @view.replace(@document_root.to_html)
      @document_root.clear_needs_update! # We've updated, we don't need to again
      @document_root.end_of_frame
      @control_interface.dispatch_event(:frame)
    end

    def run
      @document_root.needs_update!

      # This takes control of the main thread and never returns. And it *must* be run from
      # the main thread. And it stops any Ruby background threads.
      # That's totally cool and normal, right?
      @view.run
    end

    def js_bind(name, &code)
      raise "Cannot js_bind on closed or inactive Scarpe::App!" unless @view

      @view.bind(name, &code)
    end

    def js_eval(code)
      raise "Cannot js_eval on closed or inactive Scarpe::App!" unless @view

      puts "JS EVAL: #{code.inspect}" if @opts[:debug]
      @view.eval(code)
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
  end
end
