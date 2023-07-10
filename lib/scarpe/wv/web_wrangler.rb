# frozen_string_literal: true

require "webview_ruby"
require "cgi"

# WebWrangler operates in multiple phases: setup and running.

# After creation, it starts in setup mode, and you can
# use setup-mode callbacks.

class Scarpe
  class WebWrangler
    include Scarpe::Log

    attr_reader :is_running
    attr_reader :is_terminated
    attr_reader :heartbeat # This is the heartbeat duration in seconds, usually fractional
    attr_reader :control_interface

    # This error indicates a problem when running ConfirmedEval
    class JSEvalError < Scarpe::Error
      def initialize(data)
        @data = data
        super(data[:msg] || (self.class.name + "!"))
      end
    end

    # We got an error running the supplied JS code string in confirmed_eval
    class JSRuntimeError < JSEvalError
    end

    # The code timed out for some reason
    class JSTimeoutError < JSEvalError
    end

    # We got weird or nonsensical results that seem like an error on WebWrangler's part
    class InternalError < JSEvalError
    end

    # This is the JS function name for eval results
    EVAL_RESULT = "scarpeAsyncEvalResult"

    # Allow a half-second for Webview to finish our JS eval before we decide it's not going to
    EVAL_DEFAULT_TIMEOUT = 0.5

    def initialize(title:, width:, height:, resizable: false, debug: false, heartbeat: 0.1)
      log_init("WV::WebWrangler")

      @log.debug("Creating WebWrangler...")

      # For now, always allow inspect element
      @webview = WebviewRuby::Webview.new debug: true
      @webview = Scarpe::LoggedWrapper.new(@webview, "WebviewAPI") if debug
      @init_refs = {} # Inits don't go away so keep a reference to them to prevent GC

      @title = title
      @width = width
      @height = height
      @resizable = resizable
      @heartbeat = heartbeat

      # Better to have a single setInterval than many when we don't care too much
      # about the timing.
      @heartbeat_handlers = []

      # Need to keep track of which WebView Javascript evals are still pending,
      # what handlers to call when they return, etc.
      @pending_evals = {}
      @eval_counter = 0

      @dom_wrangler = DOMWrangler.new(self)

      bind("puts") do |*args|
        puts(*args)
      end

      @webview.bind(EVAL_RESULT) do |*results|
        receive_eval_result(*results)
      end

      # Ruby receives scarpeHeartbeat messages via the window library's main loop.
      # So this is a way for Ruby to be notified periodically, in time with that loop.
      @webview.bind("scarpeHeartbeat") do
        return unless @webview # I think GTK+ may continue to deliver events after shutdown

        periodic_js_callback
        @heartbeat_handlers.each(&:call)
        @control_interface.dispatch_event(:heartbeat)
      end
      js_interval = (heartbeat.to_f * 1_000.0).to_i
      @webview.init("setInterval(scarpeHeartbeat,#{js_interval})")
    end

    # Shorter name for better stack trace messages
    def inspect
      "Scarpe::WebWrangler:#{object_id}"
    end

    attr_writer :control_interface

    ### Setup-mode Callbacks

    def bind(name, &block)
      raise "App is running, javascript binding no longer works because it uses WebView init!" if @is_running

      @webview.bind(name, &block)
    end

    def init_code(name, &block)
      raise "App is running, javascript init no longer works!" if @is_running

      # Save a reference to the init string so that it goesn't get GC'd
      code_str = "#{name}();"
      @init_refs[name] = code_str

      bind(name, &block)
      @webview.init(code_str)
    end

    # Run the specified code periodically, every "interval" seconds.
    # If interface is unspecified, run per-heartbeat, which is very
    # slightly more efficient.
    def periodic_code(name, interval = heartbeat, &block)
      if interval == heartbeat
        @heartbeat_handlers << block
      else
        if @is_running
          # I *think* we need to use init because we want this done for every
          # new window. But will there ever be a new page/window? Can we just
          # use eval instead of init to set up a periodic handler and call it
          # good?
          raise "App is running, can't set up new periodic handlers with init!"
        end

        js_interval = (interval.to_f * 1_000.0).to_i
        code_str = "setInterval(#{name}, #{js_interval});"
        @init_refs[name] = code_str

        bind(name, &block)
        @webview.init(code_str)
      end
    end

    # Running callbacks

    # js_eventually is a simple JS evaluation. On syntax error, nothing happens.
    # On runtime error, execution stops at the error with no further
    # effect or notification. This is rarely what you want.
    # The js_eventually code is run asynchronously, returning neither error
    # nor value.
    #
    # This method does *not* return a promise, and there is no way to track
    # its progress or its success or failure.
    def js_eventually(code)
      raise "WebWrangler isn't running, eval doesn't work!" unless @is_running

      @log.warning "Deprecated: please do NOT use js_eventually, it's basically never what you want!" unless ENV["CI"]

      @webview.eval(code)
    end

    # Eval a chunk of JS code asynchronously. This method returns a
    # promise which will be fulfilled or rejected after the JS executes
    # or times out.
    #
    # Note that we *both* care whether the JS has finished after it was
    # scheduled *and* whether it ever got scheduled at all. If it
    # depends on tasks that never fulfill or reject then it may wait
    # in limbo, potentially forever.
    #
    # Right now we can't/don't handle arguments from previous fulfilled
    # promises. To do that, we'd probably need to know we were passing
    # in a JS function.
    EVAL_OPTS = [:timeout, :wait_for]
    def eval_js_async(code, opts = {})
      bad_opts = opts.keys - EVAL_OPTS
      raise("Bad options given to eval_with_handler! #{bad_opts.inspect}") unless bad_opts.empty?

      unless @is_running
        raise "WebWrangler isn't running, so evaluating JS won't work!"
      end

      this_eval_serial = @eval_counter
      @eval_counter += 1

      @pending_evals[this_eval_serial] = {
        id: this_eval_serial,
        code: code,
        start_time: Time.now,
        timeout_if_not_scheduled: Time.now + EVAL_DEFAULT_TIMEOUT,
      }

      # We'll need this inside the promise-scheduling block
      pending_evals = @pending_evals
      timeout = opts[:timeout] || EVAL_DEFAULT_TIMEOUT

      promise = Scarpe::Promise.new(parents: (opts[:wait_for] || [])) do
        # Are we mid-shutdown?
        if @webview
          wrapped_code = WebWrangler.js_wrapped_code(code, this_eval_serial)

          # We've been scheduled!
          t_now = Time.now
          # Hard to be sure Webview keeps a proper reference to this, so we will
          pending_evals[this_eval_serial][:wrapped_code] = wrapped_code

          pending_evals[this_eval_serial][:scheduled_time] = t_now
          pending_evals[this_eval_serial].delete(:timeout_if_not_scheduled)

          pending_evals[this_eval_serial][:timeout_if_not_finished] = t_now + timeout
          @webview.eval(wrapped_code)
          @log.debug("Scheduled JS: (#{this_eval_serial})\n#{wrapped_code}")
        else
          # We're mid-shutdown. No more scheduling things.
        end
      end

      @pending_evals[this_eval_serial][:promise] = promise

      promise
    end

    def self.js_wrapped_code(code, eval_id)
      <<~JS_CODE
        (function() {
          var code_string = #{JSON.dump code};
          try {
            result = eval(code_string);
            #{EVAL_RESULT}("success", #{eval_id}, result);
          } catch(error) {
            #{EVAL_RESULT}("error", #{eval_id}, error.message);
          }
        })();
      JS_CODE
    end

    private

    def periodic_js_callback
      time_out_eval_results
    end

    def receive_eval_result(r_type, id, val)
      entry = @pending_evals.delete(id)
      unless entry
        raise "Received an eval result for a nonexistent ID #{id.inspect}!"
      end

      @log.debug("Got JS value: #{r_type} / #{id} / #{val.inspect}")

      promise = entry[:promise]

      case r_type
      when "success"
        promise.fulfilled!(val)
      when "error"
        promise.rejected! JSRuntimeError.new(
          msg: "JS runtime error: #{val.inspect}!",
          code: entry[:code],
          ret_value: val,
        )
      else
        promise.rejected! InternalError.new(
          msg: "JS eval internal error! r_type: #{r_type.inspect}",
          code: entry[:code],
          ret_value: val,
        )
      end
    end

    # TODO: would be good to keep 'tombstone' results for awhile after timeout, maybe up to around a minute,
    # so we can detect if we're timing things out and then having them return successfully after a delay.
    # Then we could adjust the timeouts. We could also check if later serial numbers have returned, and time
    # out earlier serial numbers... *if* we're sure Webview will always execute JS evals in order.
    # This all adds complexity, though. For now, do timeouts on a simple max duration.
    def time_out_eval_results
      t_now = Time.now
      timed_out_from_scheduling = @pending_evals.keys.select do |id|
        t = @pending_evals[id][:timeout_if_not_scheduled]
        t && t_now >= t
      end
      timed_out_from_finish = @pending_evals.keys.select do |id|
        t = @pending_evals[id][:timeout_if_not_finished]
        t && t_now >= t
      end
      timed_out_from_scheduling.each do |id|
        @log.debug("JS timed out because it was never scheduled: (#{id}) #{@pending_evals[id][:code].inspect}")
      end
      timed_out_from_finish.each do |id|
        @log.debug("JS timed out because it never finished: (#{id}) #{@pending_evals[id][:code].inspect}")
      end

      # A plus *should* be fine since nothing should ever be on both lists. But let's be safe.
      timed_out_ids = timed_out_from_scheduling | timed_out_from_finish

      timed_out_ids.each do |id|
        @log.error "Timing out JS eval! #{@pending_evals[id][:code]}"
        entry = @pending_evals.delete(id)
        err = JSTimeoutError.new(msg: "JS timeout error!", code: entry[:code], ret_value: nil)
        entry[:promise].rejected!(err)
      end
    end

    public

    # After setup, we call run to go to "running" mode.
    # No more setup callbacks, only running callbacks.

    def run
      @log.debug("Run...")

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
      @webview.destroy
      @webview = nil
    end

    def destroy
      @log.debug("Destroying WebWrangler...")
      @log.debug("  (WebWrangler was already terminated)") if @is_terminated
      @log.debug("  (WebWrangler was already destroyed)") unless @webview
      if @webview && !@is_terminated
        @bindings = {}
        @webview.terminate
        @is_terminated = true
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
                font-family: arial, Helvetica, sans-serif;
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

    # Replace the entire DOM - return a promise for when this has been done.
    # This will often get rid of smaller changes in the queue, which is
    # a good thing since they won't have to be run.
    def replace(html_text)
      @dom_wrangler.request_replace(html_text)
    end

    # Request a DOM change - return a promise for when this has been done.
    def dom_change(js)
      @dom_wrangler.request_change(js)
    end

    # Return whether the DOM is, right this moment, confirmed to be fully
    # up to date or not.
    def dom_fully_updated?
      @dom_wrangler.fully_updated?
    end

    # Return a promise that will be fulfilled when all current DOM changes
    # have committed (but not necessarily any future DOM changes.)
    def dom_promise_redraw
      @dom_wrangler.promise_redraw
    end

    # Return a promise which will be fulfilled the next time the DOM is
    # fully up to date. Note that a slow trickle of changes can make this
    # take a long time, since it is *not* only changes up to this point.
    # If you want to know that some specific change is done, it's often
    # easiest to use the promise returned by dom_change(), which will
    # be fulfilled when that specific change commits.
    def promise_dom_fully_updated
      @dom_wrangler.promise_fully_updated
    end

    def on_every_redraw(&block)
      @dom_wrangler.on_every_redraw(&block)
    end
  end
end

# Leaving DOM changes as "meh, async, we'll see when it happens" is terrible for testing.
# Instead, we need to track whether particular changes have committed yet or not.
# So we add a single gateway for all DOM changes, and we make sure its work is done
# before we consider a redraw complete.
#
# DOMWrangler batches up changes - it's fine to have a redraw "in flight" and have
# changes waiting to catch the next bus. But we don't want more than one in flight,
# since it seems like having too many pending RPC requests can crash Webview. So:
# one redraw scheduled and one redraw promise waiting around, at maximum.
class Scarpe
  class WebWrangler
    class DOMWrangler
      include Scarpe::Log

      attr_reader :waiting_changes
      attr_reader :pending_redraw_promise
      attr_reader :waiting_redraw_promise

      def initialize(web_wrangler, debug: false)
        log_init("WV::WebWrangler::DOMWrangler")

        @wrangler = web_wrangler

        @waiting_changes = []
        @pending_redraw_promise = nil
        @waiting_redraw_promise = nil

        @fully_up_to_date_promise = nil

        # Initially we're waiting for a full replacement to happen.
        # It's possible to request updates/changes before we have
        # a DOM in place and before Webview is running. If we do
        # that, we should discard those updates.
        @first_draw_requested = false

        @redraw_handlers = []

        # The "fully up to date" logic is complicated and not
        # as well tested as I'd like. This makes it far less
        # likely that the event simply won't fire.
        # With more comprehensive testing, this should be
        # removable.
        web_wrangler.periodic_code("scarpeDOMWranglerHeartbeat") do
          if @fully_up_to_date_promise && fully_updated?
            @log.info("Fulfilling up-to-date promise on heartbeat")
            @fully_up_to_date_promise.fulfilled!
            @fully_up_to_date_promise = nil
          end
        end
      end

      def request_change(js_code)
        # No updates until there's something to update
        return unless @first_draw_requested

        @waiting_changes << js_code

        promise_redraw
      end

      def self.replacement_code(html_text)
        "document.getElementById('wrapper-wvroot').innerHTML = `#{html_text}`; true"
      end

      def request_replace(html_text)
        # Replace other pending changes, they're not needed any more
        @waiting_changes = [DOMWrangler.replacement_code(html_text)]
        @first_draw_requested = true

        @log.debug("Requesting DOM replacement...")
        promise_redraw
      end

      def on_every_redraw(&block)
        @redraw_handlers << block
      end

      # What are the states of redraw?
      # "empty" - no waiting promise, no pending-redraw promise, no pending changes
      # "pending only" - no waiting promise, but we have a pending redraw with some changes; it hasn't committed yet
      # "pending and waiting" - we have a waiting promise for our unscheduled changes; we can add more unscheduled
      #     changes since we haven't scheduled them yet.
      #
      # This is often called after adding a new waiting change or replacing them, so the state may have just changed.
      # It can also be called when no changes have been made and no updates need to happen.
      def promise_redraw
        if fully_updated?
          # No changes to make, nothing in-process or waiting, so just return a pre-fulfilled promise
          @log.debug("Requesting redraw but there are no pending changes or promises, return pre-fulfilled")
          return Promise.fulfilled
        end

        # Already have a redraw requested *and* one on deck? Then all current changes will have committed
        # when we (eventually) fulfill the waiting_redraw_promise.
        if @waiting_redraw_promise
          @log.debug("Promising eventual redraw of #{@waiting_changes.size} waiting unscheduled changes.")
          return @waiting_redraw_promise
        end

        if @waiting_changes.empty?
          # There's no waiting_redraw_promise. There are no waiting changes. But we're not fully updated.
          # So there must be a redraw in flight, and we don't need to schedule a new waiting_redraw_promise.
          @log.debug("Returning in-flight redraw promise")
          return @pending_redraw_promise
        end

        @log.debug("Requesting redraw with #{@waiting_changes.size} waiting changes and no waiting promise - need to schedule something!")

        # We have at least one waiting change, possibly newly-added. We have no waiting_redraw_promise.
        # Do we already have a redraw in-flight?
        if @pending_redraw_promise
          # Yes we do. Schedule a new waiting promise. When it turns into the pending_redraw_promise it will
          # grab all waiting changes. In the mean time, it sits here and waits.
          #
          # We *could* do a fancy promise thing and have it update @waiting_changes for itself, etc, when it
          # schedules itself. But we should always be calling promise_redraw or having a redraw fulfilled (see below)
          # when these things change. I'd rather keep the logic in this method. It's easier to reason through
          # all the cases.
          @waiting_redraw_promise = Promise.new

          @log.debug("Creating a new waiting promise since a pending promise is already in place")
          return @waiting_redraw_promise
        end

        # We have no redraw in-flight and no pre-existing waiting line. The new change(s) are presumably right
        # after things were fully up-to-date. We can schedule them for immediate redraw.

        @log.debug("Requesting redraw with #{@waiting_changes.size} waiting changes - scheduling a new redraw for them!")
        promise = schedule_waiting_changes # This clears the waiting changes
        @pending_redraw_promise = promise

        promise.on_fulfilled do
          @redraw_handlers.each(&:call)
          @pending_redraw_promise = nil

          if @waiting_redraw_promise
            # While this redraw was in flight, more waiting changes got added and we made a promise
            # about when they'd complete. Now they get scheduled, and we'll fulfill the waiting
            # promise when that redraw finishes. Clear the old waiting promise. We'll add a new one
            # when/if more changes are scheduled during this redraw.
            old_waiting_promise = @waiting_redraw_promise
            @waiting_redraw_promise = nil

            @log.debug "Fulfilled redraw with #{@waiting_changes.size} waiting changes - scheduling a new redraw for them!"

            new_promise = promise_redraw
            new_promise.on_fulfilled { old_waiting_promise.fulfilled! }
          else
            # The in-flight redraw completed, and there's still no waiting promise. Good! That means
            # we should be fully up-to-date.
            @log.debug "Fulfilled redraw with no waiting changes - marking us as up to date!"
            if @waiting_changes.empty?
              # We're fully up to date! Fulfill the promise. Now we don't need it again until somebody asks
              # us for another.
              if @fully_up_to_date_promise
                @fully_up_to_date_promise.fulfilled!
                @fully_up_to_date_promise = nil
              end
            else
              @log.error "WHOAH, WHAT? My logic must be wrong, because there's " +
                "no waiting promise, but waiting changes!"
            end
          end

          @log.debug("Redraw is now fully up-to-date") if fully_updated?
        end.on_rejected do
          @log.error "Could not complete JS redraw! #{promise.reason.full_message}"
          @log.debug("REDRAW FULLY UP TO DATE BUT JS FAILED") if fully_updated?

          raise "JS Redraw failed! Bailing!"

          # Later we should figure out how to handle this. Clear the promises and queues and request another redraw?
        end
      end

      def fully_updated?
        @pending_redraw_promise.nil? && @waiting_redraw_promise.nil? && @waiting_changes.empty?
      end

      # Return a promise which will be fulfilled when the DOM is fully up-to-date
      def promise_fully_updated
        if fully_updated?
          # No changes to make, nothing in-process or waiting, so just return a pre-fulfilled promise
          return Promise.fulfilled
        end

        # Do we already have a promise for this? Return it. Everybody can share one.
        if @fully_up_to_date_promise
          return @fully_up_to_date_promise
        end

        # We're not fully updated, so we need a promise. Create it, return it.
        @fully_up_to_date_promise = Promise.new
      end

      private

      # Put together the waiting changes into a new in-flight redraw request.
      # Return it as a promise.
      def schedule_waiting_changes
        return if @waiting_changes.empty?

        js_code = @waiting_changes.join(";")
        @waiting_changes = [] # They're not waiting any more!
        @wrangler.eval_js_async(js_code)
      end
    end
  end
end

# For now we don't need one of these to add DOM elements, just to manipulate them
# after initial render.
class Scarpe
  class WebWrangler
    class ElementWrangler
      attr_reader :html_id

      def initialize(html_id)
        @webwrangler = WebviewDisplayService.instance.wrangler
        @html_id = html_id
      end

      def promise_update
        @webwrangler.dom_promise_redraw
      end

      def value=(new_value)
        @webwrangler.dom_change("document.getElementById('" + html_id + "').value = `" + new_value + "`; true")
      end

      def inner_text=(new_text)
        @webwrangler.dom_change("document.getElementById('" + html_id + "').innerText = '" + new_text + "'; true")
      end

      def inner_html=(new_html)
        @webwrangler.dom_change("document.getElementById(\"" + html_id + "\").innerHTML = `" + new_html + "`; true")
      end

      def set_attribute(attribute, value)
        @webwrangler.dom_change("document.getElementById(\"" + html_id + "\").setAttribute(" + attribute.inspect + "," + value.inspect + "); true")
      end

      def remove
        @webwrangler.dom_change("document.getElementById('" + html_id + "').remove(); true")
      end

      def unmark_radio_button
        @webwrangler.dom_change("document.getElementById('#{html_id}').checked = false;")
      end

      def mark_radio_button
        @webwrangler.dom_change("document.getElementById('#{html_id}').checked = true;")
      end
    end
  end
end
