# frozen_string_literal: true

require_relative "helper"

# The fake renderer records dialog requests; headless: false never opens a real window here.
class SaveDialogTest < Minitest::Test
  include NativeTestHelpers

  def test_save_options_reach_the_renderer_and_return_the_chosen_path
    chosen = "/tmp/تصدير/اختيار.pdf"
    run = run_app(<<~APP, headless: false, script: [{ "on" => "req:dialog", "reply" => chosen }])
      Shoes.app do
        puts ask_save_file(filename: "كتاب.pdf", directory: "/tmp/تصدير", extensions: [:pdf, :txt], title: "حفظ الكتاب")
        timer(0.01) { Shoes.quit }
      end
    APP
    assert_clean_exit(run)
    assert_equal "#{chosen}\n", run.stdout
    dialog = run.of_type("req").find { |req| req["op"] == "dialog" }
    assert_equal({ "kind" => "ask_save_file", "file_name" => "كتاب.pdf", "directory" => "/tmp/تصدير",
      "extensions" => ["pdf", "txt"], "title" => "حفظ الكتاب" },
      dialog.slice("kind", "file_name", "directory", "extensions", "title"))
  end

  def test_cancel_returns_nil_and_a_plain_save_keeps_its_original_request
    run = run_app(<<~APP, headless: false, script: [
      Shoes.app do
        p ask_save_file(filename: "كتاب.pdf")
        p ask_save_file
        timer(0.01) { Shoes.quit }
      end
    APP
      { "on" => "req:dialog", "match" => { "file_name" => "كتاب.pdf" }, "reply" => nil },
    ])
    assert_clean_exit(run)
    assert_equal "nil\n\"/tmp/fake-save\"\n", run.stdout
    dialogs = run.of_type("req").select { |req| req["op"] == "dialog" }
    assert_equal 2, dialogs.length
    assert_empty dialogs.last.slice("file_name", "directory", "extensions", "title")
  end

  def test_options_respect_headless_answers_and_dialog_stubs
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app { para "Export" }
    APP
      app = Shoes.APPS.first
      options = { filename: "كتاب.pdf", directory: "/tmp/تصدير", extensions: ["pdf"], title: "حفظ الكتاب" }
      assert_nil app.ask_save_file(**options)
      stub_dialog(:ask_save_file, "/tmp/chosen.pdf")
      assert_equal "/tmp/chosen.pdf", app.ask_save_file(**options)
      assert_nil app.ask_save_file(**options)
    TEST
    assert_spec_passed(run)
    assert_empty run.of_type("req").select { |req| req["op"] == "dialog" }, "headless saves never ask for an OS dialog"
  end
end
