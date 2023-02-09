# frozen_string_literal: true

require "webview_ruby"

# WebWrangler operates in multiple phases: setup and running.

# After creation, it starts in setup mode, and you can
# use setup-mode callbacks.

class Scarpe
  class WebWrangler
    attr_reader :webview

    def initialize(title:, width:, height:, debug:)
      # For now, always allow inspect element
      @webview = WebviewRuby::Webview.new debug: true

      @title = title
      @width = width
      @height = height
      @debug = debug
    end

    ### Setup-mode Callbacks

    def bind(name, &block)
      raise "App is running, javascript binding no longer works because it uses WebView init!" if @is_running

      puts "Binding #{name} to #{block.inspect}" if @debug
      @webview.bind(name, &block)
    end

    def init_code(name, &block)
      raise "App is running, javascript init no longer works!" if @is_running

      puts "Init code #{name}" if @debug
      @webview.bind(name, &block)
      @webview.init("#{name}();")
    end

    def periodic_code(name, interval, &block)
      raise "App is running, javascript periodic-code init no longer works!" if @is_running

      puts "Periodic callback #{name}" if @debug
      @webview.bind(name, &block)
      js_interval = (interval.to_f * 1_000.0).to_i
      @webview.init("setInterval(scarpePeriodicCallback, #{js_interval});")
    end

    # Running callbacks

    def eval(code)
      puts "Eval code: #{code.inspect}" if @debug
      @webview.eval(code)
    end

    # After setup, we call run to go to "running" mode.
    # No more setup callbacks, only running callbacks.

    def run
      puts "Run..." if @debug
      @webview.bind("puts") do |*args|
        puts(*args)
      end

      @webview.set_title(@title)
      @webview.set_size(@width, @height)
      @webview.navigate("data:text/html, #{empty}")

      monkey_patch_console(@webview)

      @is_running = true
      @webview.run
      @is_running = false
    end

    def destroy
      @webview.terminate
      @webview.destroy
      @webview = nil
    end

    private

    # TODO: can this be an init()?
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

    def empty
      "<body id='body-wvroot'><div id='wrapper-wvroot'></div></body>"
    end

    public

    # For now, the WebWrangler gets a bunch of fairly low-level requests
    # to mess with the HTML DOM. This needs to be turned into a nicer API,
    # but first we'll get it all into one place and see what we're doing.

    # Replace the entire DOM
    def replace(el)
      @webview.eval("document.getElementById('wrapper-wvroot').innerHTML = `#{el}`;")
    end
  end
end

# For now we don't need one of these to add DOM elements, just to manipulate them
# after initial render.
class Scarpe
  class WebWrangler
    class Element
      attr_reader :html_id

      def initialize(webview, html_id)
        @webview = webview
        @html_id = html_id
      end

      def value=(new_value)
        @webview.eval("document.getElementById(#{html_id}).value = #{new_value}")
      end

      def inner_text=(new_text)
        @webview.eval("document.getElementById(#{html_id}).inner_text = '#{new_text}'")
      end

      def inner_html=(new_html)
        @webview.eval("document.getElementById(#{html_id}).inner_text = `#{new_html}`")
      end

      def remove
        @webview.eval("document.getElementById(#{html_id}).remove()")
      end
    end
  end
end
