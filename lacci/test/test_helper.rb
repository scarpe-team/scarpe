# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "shoes"

require "scarpe/components/unit_test_helpers"
require "scarpe/components/minitest_result"

require "minitest/autorun"

require "minitest/reporters"
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

# For testing Lacci, it's kind of silly to start a Webview application.
# They're slow, unreliable and memory-hungry. So instead we start a
# Niente do-nothing application for a simple API test. It's a lot like
# mocking.
class NienteTest < Minitest::Test
  include ::Scarpe::Test::Helpers

  SCARPE_EXE = File.expand_path("../../exe/scarpe", __dir__)

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
      system(
        "LOCALAPPDATA=\"#{Dir.tmpdir}\" " +
        "NIENTE_LOG_LEVEL=#{log_level} " +
        "SHOES_SPEC_TEST=\"#{shoes_spec_path}\" " +
        "SCARPE_DISPLAY_SERVICE=\"#{display_service}\" " +
        "SHOES_MINITEST_EXPORT_FILE=#{sspec_file} " +
        "SHOES_MINITEST_CLASS_NAME=\"#{class_name}\" " +
        "SHOES_MINITEST_METHOD_NAME=\"#{method_name}\" " +
        "ruby #{SCARPE_EXE} --dev #{test_app_location}"
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
