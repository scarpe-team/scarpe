# frozen_string_literal: true

require "webview_ruby"
require "securerandom"
require "json"

require_relative "scarpe/dimensions"
require_relative "scarpe/html"
require_relative "scarpe/container"
require_relative "scarpe/version"
require_relative "scarpe/para"
require_relative "scarpe/stack"
require_relative "scarpe/flow"
require_relative "scarpe/button"
require_relative "scarpe/image"
require_relative "scarpe/edit_box"
require_relative "scarpe/edit_line"
require_relative "scarpe/alert"
require_relative "scarpe/js_eval"
require_relative "scarpe/internal_app"

module Scarpe
  # Scarpe::App should only be used from the main thread, due to GTK+ limitations.
  class App
    VALID_OPTS = [:debug, :init_code, :result_filename, :periodic_time, :die_after]

    def initialize(opts = {}, &app_code_body)
      bad_opts = opts.keys - VALID_OPTS
      raise "Illegal options to Scarpe::App.initialize! #{bad_opts.inspect}" unless bad_opts.empty?
      @opts = opts
      @app_code_body = app_code_body
    end

    def init
      do_debug = @opts[:debug] ? true : false

      puts "INIT APP" if do_debug

      @w = WebviewRuby::Webview.new debug: do_debug
      @internal_app = Scarpe::InternalApp.new(@w, { debug: do_debug })
      scarpe_app = self

      @w.bind("scarpeInit") do
        @internal_app.render(&@app_code_body)
        monkey_patch_console(@w)
      end

      @w.bind("scarpeHandler") do |*args|
        @internal_app.handle_callback(*args)
      end

      @w.bind("puts") do |*args|
        puts(*args)
      end

      # Used to make sure Ruby code can periodically run.
      @w.bind("scarpePeriodicCallback") do |*args|
        if @opts[:die_after]
          if (Time.now - @t_start).to_f > @opts[:die_after]
            scarpe_app.destroy
          end
        end
      end

      @w.bind("scarpeExit") do
        scarpe_app.destroy
      end

      result_file = @opts[:result_filename] || "./scarpe_results.txt"
      @w.bind("scarpeStatusAndExit") do |*results|
        puts "Writing results file #{result_file.inspect} to disk!" if @opts[:debug]
        File.open(result_file, "w") { |f| f.write(JSON.pretty_generate results) }
        scarpe_app.destroy
      end
    end

    def run
      puts "RUN APP" if @opts[:debug]

      init_code = @opts[:init_code] || ""
      @t_start = Time.now
      t_interval = @opts[:periodic_time] || 0.1
      js_interval = (t_interval.to_f * 1_000.0).to_i
      @w.init("scarpeInit(); setInterval(scarpePeriodicCallback, #{js_interval}) #{init_code};")
      @w.set_title("example")
      @w.set_size(480, 320)
      @w.navigate("data:text/html, <body id=#{@internal_app.object_id}></body>")

      # This takes control of the main thread and never returns. And it *must* be run from
      # the main thread. And it stops any Ruby background threads.
      # That's totally cool and normal, right?
      @w.run
    end

    # Uses init() internally, so it won't work once run() is called
    def js_bind(name, &code)
      raise "Cannot js_bind on closed or inactive Scarpe::App!" unless @w
      @w.bind(name, &code)
    end

    def js_eval(code)
      raise "Cannot js_eval on closed or inactive Scarpe::App!" unless @w
      puts "JS EVAL: #{code.inspect}" if @opts[:debug]
      @w.eval(code)
    end

    def destroy
      puts "DESTROY APP" if @opts[:debug]
      puts "  (but app was already inactive or destroyed)" if @opts[:debug] && @w == nil && @internal_app == nil
      @internal_app = nil
      if @w
        @w.terminate
        @w.destroy
        @w = nil
      end
    end

    private

    def monkey_patch_console(window)
      # this forwards all console.log/info/error/warn calls also
      # to the terminal that is running the scarpe app
      window.eval <<~JS
      function patchConsole(fn) {
        const original = console[fn];
        console[fn] = function(...args) {
          original(...args);
          puts(...args);
        }
      };
      patchConsole('log');
      patchConsole('info');
      patchConsole('error');
      patchConsole('warn');
      JS
    end
  end

  def self.app(opts = {}, &blk)
    app = Scarpe::App.new(opts, &blk)
    app.init
    app.run
    app.destroy
  end
end
