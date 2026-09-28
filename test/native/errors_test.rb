# frozen_string_literal: true

require_relative "helper"

# Where an app's errors go (DESIGN 5.6): Shoes.on_error hears each one a handler, a timer or
# the startup raises (ledger K9), and the Shoes console lists them (K8, H10), which Alt-/
# (Cmd-/ on a Mac) and Shoes.show_console open, and nothing else does.
class ErrorsTest < Minitest::Test
  include NativeTestHelpers

  def setup
    skip_without_real_binary
  end

  def test_alt_slash_opens_the_console_with_what_came_before
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        $keys = []
        keypress { |key| $keys << key }
        para "an app with a problem"
      end
    APP
      begin
        raise ArgumentError, "the sprockets are jammed"
      rescue => e
        Shoes.report_error(e, during: "handler") # as a handler's error reaches it
      end
      info "the kettle is on"
      assert_equal 1, Shoes.APPS.size, "an error never opens the console by itself"

      press_key "alt_/"
      wait_frames
      assert_empty $keys, "the app never hears Alt-/"
      assert_equal 2, Shoes.APPS.size, "the console opens in a window of its own"
      console = Shoes.APPS.last
      assert_equal "Shoes Console", console.style[:title]
      texts = -> { console.all_drawables.grep(Shoes::Para).map(&:text) }
      jammed = texts.call.index { |t| t.include?("ArgumentError: the sprockets are jammed") }
      kettle = texts.call.index { |t| t.include?("the kettle is on") }
      refute_nil jammed, "the error is listed"
      refute_nil kettle, "and the info line"
      assert_operator kettle, :<, jammed, "newest first"
      assert texts.call.any? { |t| t.include?("in a handler") && t.include?("line") }, "an error says where it happened"

      press_key "alt_/"
      assert_equal 2, Shoes.APPS.size, "Alt-/ again keeps the one console"
      assert_same console, Shoes.show_console, "and so does Shoes.show_console"

      debug "one more thing"
      advance 0.5
      assert texts.call.any? { |t| t.include?("one more thing") }, "a line that comes while it is open shows up"

      click_on button("Clear")
      assert texts.call.none? { |t| t.include?("the sprockets are jammed") }, "Clear empties it"
      assert_empty Shoes::Console.entries
    TEST
    assert_spec_passed(run)
  end

  def test_show_console_opens_it_and_scarpe_warnings_are_listed
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app { para "a quiet app" }
    APP
      Shoes::Log.logger("Scarpe::Native::Normalize").warn("a colour it could not read")
      console = Shoes.show_console
      wait_frames
      assert_equal "Shoes Console", console.style[:title]
      texts = console.all_drawables.grep(Shoes::Para).map(&:text)
      assert texts.any? { |t| t.include?("a colour it could not read") }, "Scarpe's own warnings are listed"
    TEST
    assert_spec_passed(run)
  end

  # Shoes.on_error in an ordinary app: a handler, a timer and the startup each reach it, with
  # the program going on after the first two. (Test code surfaces errors instead, so these run
  # without it.)
  def test_shoes_on_error_hears_handlers_timers_and_startup
    run = run_real(<<~APP, timeout: 30)
      Shoes.on_error { |err| $stdout.puts "ON_ERROR \#{JSON.generate(err.slice("class", "message", "line", "during"))}" }
      Shoes.app do
        @boom = button("Boom") { raise ArgumentError, "the button broke" }
        timer(0.1) { Scarpe::Native::DisplayService.instance.child.request(:click, target: { id: @boom.linkable_id }) }
        timer(0.3) { raise "the timer broke" }
        timer(0.6) { Shoes.quit }
      end
    APP
    assert_clean_exit(run)
    heard = run.stdout.lines.grep(/\AON_ERROR /).map { |line| JSON.parse(line.delete_prefix("ON_ERROR ")) }
    assert_equal [
      { "class" => "ArgumentError", "message" => "the button broke", "line" => 3, "during" => "handler" },
      { "class" => "RuntimeError", "message" => "the timer broke", "line" => 5, "during" => "timer" },
    ], heard
    assert_includes run.stderr, "ArgumentError: the button broke", "and each is logged as before"

    run = run_real(<<~APP, timeout: 30)
      Shoes.on_error { |err| $stdout.puts "ON_ERROR \#{JSON.generate(err.slice("class", "line", "during"))}" }
      Shoes.app do
        para "starting"
        raise NameError, "a name nobody gave"
      end
    APP
    refute run.status.success?, "a startup error still ends the app"
    assert_includes run.stdout, 'ON_ERROR {"class":"NameError","line":4,"during":"startup"}'
  end

  # An animation that raises raises every frame, in words that may change each time. The log,
  # which a packaged app keeps on disk, says it once, then how often, as the count reaches 10,
  # 100 and so on; Shoes.on_error and the console still hear every one.
  def test_an_error_raised_again_and_again_is_logged_once_then_counted
    run = run_real(<<~APP, timeout: 30)
      $heard = 0
      Shoes.on_error { |err| $heard += 1 }
      Shoes.app do
        animate(100) { |i| [1, 2, 3].fetch(i + 3) }
        timer(1.5) do
          listed = Shoes::Console.entries.count { |entry| entry.message.start_with?("IndexError") }
          $stdout.puts "HEARD \#{$heard} LISTED \#{listed}"
          Shoes.quit
        end
      end
    APP
    assert_clean_exit(run)
    said = run.stdout.match(/HEARD (\d+) LISTED (\d+)/)
    refute_nil said, "the app said how many it heard\n#{run.stdout}"
    heard, listed = said.captures.map(&:to_i)
    assert_operator heard, :>=, 20, "Shoes.on_error hears every frame's error"
    assert_equal heard, listed, "and the console lists every one"
    logged = run.stderr.lines.grep(/IndexError/)
    assert_match(/IndexError: index 3 outside of array bounds.* in the .*app\.rb:4/, logged.first, "the first is logged in full")
    assert_includes logged[1].to_s, "10 times now", "then the count at 10"
    assert_operator logged.size, :<=, 3, "and no line a frame:\n#{logged.first(6).join}"
  end
end
