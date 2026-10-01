# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
# Also add the main scarpe lib for turtle and other display-side code
$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
require "shoes"

require "scarpe/components/unit_test_helpers"
require "scarpe/components/minitest_result"

require "minitest/autorun"
require "tmpdir"
require "fileutils"

require "minitest/reporters"
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

# For testing Lacci, it's kind of silly to start a Webview application.
# They're slow, unreliable and memory-hungry. So instead we start a
# Niente do-nothing application for a simple API test. It's a lot like
# mocking.
class NienteTest < Minitest::Test
  include ::Scarpe::Test::Helpers

  SCARPE_EXE = File.expand_path("../../exe/scarpe", __dir__)

  # Each test app keeps its clipboard in a file of its own (SCARPE_CLIPBOARD_FILE), and runs
  # with spec/support/fakebin first on PATH, as spec/run does (spec/README.md rule 6), so no
  # test touches the real clipboard or opens a dialog.
  FAKEBIN = File.expand_path("../../spec/support/fakebin", __dir__)
  CLIPBOARDS = Dir.mktmpdir("lacci-test-clipboards")
  Minitest.after_run { FileUtils.rm_rf(CLIPBOARDS) }

  # The file this test's app reads and writes as the clipboard.
  def clipboard_file
    File.join(CLIPBOARDS, "#{self.class}-#{name}.txt")
  end

  def run_test_niente_code(
    scarpe_app_code,
    test_extension: ".rb",
    **opts
  )
    with_tempfile(["scarpe_test_app", test_extension], scarpe_app_code) do |test_app_location|
      run_test_niente_app(test_app_location, **opts)
    end
  end

  def run_test_niente_app(
    test_app_location,
    app_test_code: "",
    timeout: 5.0,
    class_name: self.class,
    method_name: self.name,
    expect_process_fail: false,
    expect_minitest_exception: false,
    display_service: "niente",
    log_level: "warn"
  )
    sspec_file = File.expand_path(File.join __dir__, "niente_test.json")
    File.unlink sspec_file rescue nil

    with_tempfiles([
      #["scarpe_log_config.json", JSON.dump(log_config_for_test)],
      [["shoes_spec_code", ".rb"], app_test_code],
    ]) do |shoes_spec_path,_|
      # The environment goes as a Hash: a "VAR=x ruby ..." string needs a Unix shell
      system(
        {
          "LOCALAPPDATA" => Dir.tmpdir,
          "PATH" => [FAKEBIN, ENV["PATH"]].join(File::PATH_SEPARATOR),
          "SPEC_CLIPBOARD_FILE" => clipboard_file,
          "SCARPE_CLIPBOARD_FILE" => clipboard_file,
          "NIENTE_LOG_LEVEL" => log_level.to_s,
          "SHOES_SPEC_TEST" => shoes_spec_path,
          "SCARPE_DISPLAY_SERVICE" => display_service.to_s,
          "SHOES_MINITEST_EXPORT_FILE" => sspec_file,
          "SHOES_MINITEST_CLASS_NAME" => class_name.to_s,
          "SHOES_MINITEST_METHOD_NAME" => method_name.to_s,
        },
        "ruby", SCARPE_EXE, "--dev", test_app_location,
      )
    end

    if expect_process_fail
      assert(false, "Expected app to fail but it succeeded!") if $?.success?
      return
    end

    # Check if the process exited normally or crashed (segfault, failure, timeout)
    unless $?.success?
      assert(false, "App failed with exit code: #{$?.exitstatus}")
      return
    end

    result = Scarpe::Components::MinitestResult.new(sspec_file)
    if result.error?
      if expect_minitest_exception
        assert_equal true, true
      else
        raise result.error_message
      end
    elsif result.fail?
      assert false, result.fail_message
    elsif result.skip?
      skip
    else
      # Count out the correct number of assertions
      result.assertions.times { assert true }
    end
  end
end
