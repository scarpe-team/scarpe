# frozen_string_literal: true

require "webview_ruby"
require "cgi"

# WebWrangler operates in multiple phases: setup and running.

# After creation, it starts in setup mode, and you can
# use setup-mode callbacks.

class Scarpe
  class WebWrangler
    def initialize(title:, width:, height:, resizable:, debug:)
      # For now, always allow inspect element
      @webview = WebviewRuby::Webview.new debug: true

      @title = title
      @width = width
      @height = height
      @resizable = resizable
      @debug = debug

      puts "Creating WebWrangler..." if debug

      @webview.bind("puts") do |*args|
        puts(*args)
      end
    end

    ### Setup-mode Callbacks

    def bind(name, &block)
      raise "App is running, javascript binding no longer works because it uses WebView init!" if @is_running

      @webview.bind(name, &block)
    end

    def init_code(name, &block)
      raise "App is running, javascript init no longer works!" if @is_running

      @webview.bind(name, &block)
      @webview.init("#{name}();")
    end

    def periodic_code(name, interval, &block)
      raise "App is running, javascript periodic-code init no longer works!" if @is_running

      @webview.bind(name, &block)
      js_interval = (interval.to_f * 1_000.0).to_i
      @webview.init("setInterval(#{name}, #{js_interval});")
    end

    # Running callbacks

    def js_eval(code)
      @webview.eval(code)
    end

    # After setup, we call run to go to "running" mode.
    # No more setup callbacks, only running callbacks.

    def run
      puts "Run..." if @debug

      # From webview:
      # 0 - Width and height are default size
      # 1 - Width and height are minimum bonds
      # 2 - Width and height are maximum bonds
      # 3 - Window size can not be changed by a user
      hint = @resizable ? 0 : 3

      @webview.set_title(@title)
      @webview.set_size(@width, @height, hint)
      @webview.navigate("data:text/html, #{empty}")

      monkey_patch_console(@webview)

      @is_running = true
      @webview.run
      @is_running = false
    end

    def destroy
      puts "Destroying WebWrangler..." if @debug
      puts "  (But WebWrangler was already inactive)" if @debug && !@webview
      if @webview
        @webview.terminate
        @webview.destroy
        @webview = nil
      end
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
      html = <<~HTML
        <html>
          <head id='head-wvroot'>
            <style id='style-wvroot'>
              /** Style resets **/
              body {
                margin: 0;
                height: 100%;
                overflow: hidden;
              }

              p {
                margin: 0;
              }
            </style>
          </head>
          <body id='body-wvroot'>
            <div id='wrapper-wvroot'></div>
          </body>
        </html>
      HTML

      CGI.escape(html)
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
    class ElementWrangler
      attr_reader :html_id

      def initialize(webwrangler, html_id)
        @webwrangler = webwrangler
        @html_id = html_id
      end

      def value=(new_value)
        @webwrangler.js_eval("document.getElementById(#{html_id}).value = #{new_value}")
      end

      def inner_text=(new_text)
        @webwrangler.js_eval("document.getElementById(#{html_id}).innerText = '#{new_text}'")
      end

      def inner_html=(new_html)
        @webwrangler.js_eval("document.getElementById(#{html_id}).innerHTML = `#{new_html}`")
      end

      def remove
        @webwrangler.js_eval("document.getElementById(#{html_id}).remove()")
      end
    end
  end
end
