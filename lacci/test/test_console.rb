# frozen_string_literal: true

require_relative "test_helper"

# The Shoes console (manual 719-844, ledger K3, K8): debug, info and error go there, and so do
# the errors blocks raise; Shoes.show_console opens it, and nothing opens it by itself.
class TestConsoleLog < Minitest::Test
  # Other tests share this process's console.
  def setup
    Shoes::Console.clear!
  end

  def teardown
    Shoes::Console.clear!
  end

  def test_lines_are_kept_oldest_first_up_to_a_limit
    (Shoes::Console::LIMIT + 5).times { |i| Shoes::Console.log(:info, "line #{i}") }
    entries = Shoes::Console.entries
    assert_equal Shoes::Console::LIMIT, entries.size
    assert_equal "line 5", entries.first.message, "the oldest go first"
    assert_equal entries.map(&:seq).sort, entries.map(&:seq), "in the order they came"
    Shoes::Console.clear!
    assert_empty Shoes::Console.entries
  end

  def test_lines_nobody_reads_are_kept_to_the_limit_too
    Shoes::Console.entries
    (Shoes::Console::LIMIT * 3).times { |i| Shoes::Console.log(:warn, "warning #{i}") }
    assert_operator Shoes::Console.instance_variable_get(:@incoming).size, :<=, Shoes::Console::LIMIT
    assert_equal "warning #{Shoes::Console::LIMIT * 3 - 1}", Shoes::Console.entries.last.message
  end

  def test_an_unknown_level_is_info
    Shoes::Console.log(:shouting, "hello")
    assert_equal :info, Shoes::Console.entries.last.level
  end

  # A line may come from a signal trap (Lacci's own INT trap logs), where a Mutex is off limits.
  def test_a_line_can_come_from_a_signal_trap
    skip "Windows has no USR1" if Gem.win_platform?
    previous = Signal.trap("USR1") { Shoes::Console.log(:warn, "from a trap") }
    Process.kill("USR1", Process.pid)
    sleep 0.05 until Shoes::Console.entries.any? { |e| e.message == "from a trap" }
    assert_equal :warn, Shoes::Console.entries.last.level
  ensure
    Signal.trap("USR1", previous || "DEFAULT") unless Gem.win_platform?
  end

  def test_the_log_builtins_reach_the_console_and_still_print
    reporter = Object.new
    out, err = capture_io do
      assert_nil reporter.debug("the sprocket turned")
      assert_nil reporter.info("the kettle is on")
      assert_nil reporter.error("the sprockets are jammed")
      begin
        raise ArgumentError, "the flux capacitor jammed"
      rescue => e
        reporter.error(e)
      end
    end
    assert_includes out, "the kettle is on"
    assert_includes err, "ArgumentError: the flux capacitor jammed"
    levels = Shoes::Console.entries.map { |e| [e.level, e.message] }
    assert_equal [[:debug, "the sprocket turned"], [:info, "the kettle is on"], [:error, "the sprockets are jammed"],
      [:error, "ArgumentError: the flux capacitor jammed"]], levels
    assert_includes Shoes::Console.entries.last.where, File.basename(__FILE__), "an exception says where it came from"
  end
end

class TestConsoleWindow < NienteTest
  # A string with bad bytes "will show up in the console" (manual 482-485, ledger F12).
  def test_text_with_bad_bytes_is_reported_on_the_console
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app { para "caf\\xE9" }
    SHOES_APP
      reported = Shoes::Console.entries.find { |e| e.message.include?("text is not valid UTF-8") }
      refute_nil reported, "the console lists it"
      assert_equal :error, reported.level
    SHOES_SPEC
  end

  def test_show_console_opens_a_window_listing_newest_first
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        info "first"
        @log = button("Log") { debug "second" }
        @open = button("Console") { Shoes.show_console }
      end
    SHOES_APP
      assert_equal 1, Shoes.APPS.size, "nothing opens it by itself"
      button("@log").trigger_click
      button("@open").trigger_click
      assert_equal 2, Shoes.APPS.size, "it opens in a window of its own"
      console = Shoes.APPS.last
      assert_equal "Shoes Console", console.style[:title]
      texts = console.all_drawables.select { |d| d.is_a?(Shoes::Para) }.map(&:text)
      first = texts.index("first")
      second = texts.index("second")
      refute_nil first
      refute_nil second
      assert_operator second, :<, first, "newest first"

      button("@open").trigger_click
      assert_equal 2, Shoes.APPS.size, "one console at a time"
      assert_same console, Shoes.show_log, "Shoes 3's name opens the same one"
    SHOES_SPEC
  end
end
