# frozen_string_literal: true

class Scarpe
  # Scarpe::App must only be used from the main thread, due to GTK+ limitations.
  class App
    # TODO: Do something with resizable in the future.
    # For now, we accept it as a valid option so it doesn't crash examples.
    VALID_OPTS = [:debug, :test_assertions, :init_code, :result_filename, :periodic_time, :die_after, :resizable]

    attr_reader :do_debug

    def initialize(title: "Scarpe!", width: 480, height: 420, **opts, &app_code_body)
      bad_opts = opts.keys - VALID_OPTS
      raise "Illegal options to Scarpe::App.initialize! #{bad_opts.inspect}" unless bad_opts.empty?

      @title = title
      @width = width
      @height = height

      @do_debug = opts[:debug] ? true : false
      @view = Scarpe::WebWrangler.new title: title, width: width, height: height, debug: do_debug
      @document_root = Scarpe::DocumentRoot.new(@view, { debug: do_debug })

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

      # We want a timer if timer/timeout options are specified, or if we need to ensure timeouts for tests
      if @opts[:test_assertions] || @opts[:die_after] || @opts[:periodic_time]
        # Used to make sure Ruby code can periodically run.
        @view.periodic_code("scarpePeriodicCallback", @opts[:periodic_time] || 0.1) do |*_args|
          # @t_start is set on run()
          if @opts[:die_after] && ((Time.now - @t_start).to_f > @opts[:die_after])
            scarpe_app.destroy
          end
        end
      end

      if @opts[:test_assertions]
        result_file = @opts[:result_filename] || "./scarpe_results.txt"
        @view.bind("scarpeStatusAndExit") do |*results|
          puts "Writing results file #{result_file.inspect} to disk!" if @opts[:debug]
          File.open(result_file, "w") { |f| f.write(JSON.pretty_generate(results)) }
          scarpe_app.destroy
        end
      end

      if @opts[:init_code]
        @view.init_code("scarpeUserInitCode", @opts[:init_code] + ";")
      end
    end

    # Draw a frame, call the per-frame callback(s)
    def redraw_frame
      @view.replace(@document_root.to_html)
      @document_root.clear_needs_update! # We've updated, we don't need to again
      @document_root.end_of_frame
    end

    def run
      @t_start = Time.now
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
      @document_root = nil
      if @view
        @view.destroy
        @view = nil
      end
    end
  end
end
