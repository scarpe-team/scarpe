# frozen_string_literal: true

require_relative "test_helper"

# DESIGN.md section 10, item 6. A display that answers a builtin with nil
# (a cancelled file dialog) has answered; only an unanswered builtin may
# fall back to an osascript dialog.
class TestBuiltinResponse < Minitest::Test
  def test_nil_counts_as_an_answer
    Shoes::DisplayService.clear_builtin_response
    refute Shoes::DisplayService.builtin_response?

    Shoes::DisplayService.set_builtin_response(nil)
    assert Shoes::DisplayService.builtin_response?
    assert_nil Shoes::DisplayService.consume_builtin_response
    refute Shoes::DisplayService.builtin_response?
  end

  def test_shoes_rgb_exists_for_ask_color
    assert_equal [10, 20, 30, 255], Shoes.rgb(10, 20, 30)
  end

  # Ledger K3: error(message) reaches the console and returns nil; an exception comes
  # out as its class and message (manual 732-739).
  def test_error_reports_messages_and_exceptions
    reporter = Object.new
    out, err = capture_io do
      assert_nil reporter.error("The sprockets are jammed")
      reporter.error(ArgumentError.new("the flux capacitor jammed"))
    end
    assert_includes out + err, "The sprockets are jammed"
    assert_includes out + err, "ArgumentError: the flux capacitor jammed"
  end
end

class TestBuiltins < NienteTest
  # Every test here replaces the osascript fallback on the app first,
  # so a regression can never open a real dialog.
  def test_nil_answer_does_not_fall_back
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        define_singleton_method(:native_builtin_fallback) { |*_args| :fell_back }
      end
    SHOES_APP
      app = Shoes.APPS[0]
      handler = Shoes::DisplayService.subscribe_to_event("builtin", nil) do |cmd_name, _args|
        Shoes::DisplayService.set_builtin_response(nil) if cmd_name == "ask_open_file"
      end
      assert_nil app.send(:shoes_builtin, "ask_open_file")
      Shoes::DisplayService.unsub_from_events(handler)
    SHOES_SPEC
  end

  def test_niente_answers_dialogs_headlessly
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        define_singleton_method(:native_builtin_fallback) { |*_args| :fell_back }
        @answers = [confirm("Sure?"), ask("Name?"), ask_open_file, ask_color("Pick")]
      end
    SHOES_APP
      assert_equal [false, "", nil, nil], Shoes.APPS[0].instance_variable_get(:@answers)
    SHOES_SPEC
  end

  # Ledger K1: ask takes secret: and title:, and hands them to the display.
  def test_ask_passes_its_options_on
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        define_singleton_method(:native_builtin_fallback) { |*_args| :fell_back }
        $asked = []
        Shoes::DisplayService.subscribe_to_event("builtin", nil) do |cmd_name, args|
          $asked << args if cmd_name == "ask"
        end
        ask("Password?", secret: true, title: "Log in")
        ask("Name?")
      end
    SHOES_APP
      assert_equal [["Password?", { secret: true, title: "Log in" }], ["Name?"]], $asked
    SHOES_SPEC
  end
end
