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
      :resizable,       # the app is resizable
      :no_control,      # do not run a test-control file, even if one is specified in SCARPE_TEST_CONTROL
    ]

    attr_reader :do_debug
    attr_reader :control_interface

    def initialize(title: "Scarpe!", width: 480, height: 420, resizable: true, **opts, &app_code_body)
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

      @do_debug = opts[:debug] ? true : false
      @view = Scarpe::WebWrangler.new title:, width:, height:, resizable:, debug: do_debug
      @document_root = Scarpe::DocumentRoot.new(@view, { debug: do_debug })

      @view.on_every_redraw {
        @control_interface.dispatch_event(:redraw)
      }

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
        # This will cause the initial needs_update!, which will cause the redraw
        @document_root.instance_eval(&@app_code_body)
      end

      @view.bind("scarpeHandler") do |*args|
        @document_root.handle_callback(*args)
      end

      @view.bind("scarpeExit") do
        scarpe_app.destroy
      end
    end

    def run
      @control_interface.dispatch_event(:init)

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
  end
end
