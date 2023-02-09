# frozen_string_literal: true

class Scarpe
  # Scarpe::App must only be used from the main thread, due to GTK+ limitations.
  class App
    VALID_OPTS = [:debug, :test_assertions, :init_code, :result_filename, :periodic_time, :die_after]

    def initialize(title: "Scarpe!", width: 480, height: 420, **opts, &app_code_body)
      bad_opts = opts.keys - VALID_OPTS
      raise "Illegal options to Scarpe::App.initialize! #{bad_opts.inspect}" unless bad_opts.empty?
      @title = title
      @width = width
      @height = height
      @opts = opts
      @app_code_body = app_code_body
    end

    def init
      do_debug = @opts[:debug] ? true : false

      puts "INIT APP" if do_debug

      @w = WebviewRuby::Webview.new debug: do_debug
      @document_root = Scarpe::DocumentRoot.new(@w, { debug: do_debug })
      scarpe_app = self

      @w.bind("scarpeInit") do
        monkey_patch_console(@w)
        @document_root.instance_eval(&@app_code_body)
        redraw_frame
      end
      @w.init("scarpeInit();")

      @w.bind("scarpeHandler") do |*args|
        @document_root.handle_callback(*args)
      end

      @w.bind("puts") do |*args|
        puts(*args)
      end

      @w.bind("scarpeExit") do
        scarpe_app.destroy
      end

      @w.bind("scarpeRedrawCallback") do
        puts("Redraw!") if do_debug
        redraw_frame if @document_root.redraw_requested
      end

      # We want a timer if timer/timeout options are specified, or if we need to ensure timeouts for tests
      if @opts[:test_assertions] || @opts[:die_after] || @opts[:periodic_time]
        # Used to make sure Ruby code can periodically run.
        @w.bind("scarpePeriodicCallback") do |*args|
          if @opts[:die_after]
            # @t_start is set on run()
            if (Time.now - @t_start).to_f > @opts[:die_after]
              scarpe_app.destroy
            end
          end
        end

        t_interval = @opts[:periodic_time] || 0.1
        js_interval = (t_interval.to_f * 1_000.0).to_i
        @w.init("setInterval(scarpePeriodicCallback, #{js_interval});")
      end

      if @opts[:test_assertions]
        result_file = @opts[:result_filename] || "./scarpe_results.txt"
        @w.bind("scarpeStatusAndExit") do |*results|
          puts "Writing results file #{result_file.inspect} to disk!" if @opts[:debug]
          File.open(result_file, "w") { |f| f.write(JSON.pretty_generate results) }
          scarpe_app.destroy
        end
      end

      if @opts[:init_code]
        @w.init(@opts[:init_code] + ";")
      end
    end

    # Draw a frame, call the per-frame callback(s)
    def redraw_frame
      @document_root.replace(@document_root.to_html)
      @document_root.clear_needs_update! # We've updated, we don't need to again
      @document_root.end_of_frame
    end

    def run
      puts "RUN APP" if @opts[:debug]

      @t_start = Time.now
      @w.set_title(@title)
      @w.set_size(@width, @height)
      @document_root.needs_update!
      @w.navigate("data:text/html, #{@document_root.empty}")

      # This takes control of the main thread and never returns. And it *must* be run from
      # the main thread. And it stops any Ruby background threads.
      # That's totally cool and normal, right?
      @is_running = true
      @w.run
      @is_running = false
    end

    def js_bind(name, &code)
      raise "Cannot js_bind on closed or inactive Scarpe::App!" unless @w
      raise "App is running, js_bind no longer works because it uses WebView init!" if @is_running
      @w.bind(name, &code)
    end

    def js_eval(code)
      raise "Cannot js_eval on closed or inactive Scarpe::App!" unless @w
      puts "JS EVAL: #{code.inspect}" if @opts[:debug]
      @w.eval(code)
    end

    def destroy
      puts "DESTROY APP" if @opts[:debug]
      puts "  (but app was already inactive or destroyed)" if @opts[:debug] && @w == nil && @document_root == nil
      @document_root = nil
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
end
