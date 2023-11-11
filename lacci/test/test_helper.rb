# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "shoes"

require "scarpe/components/unit_test_helpers"

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
    display_service: "niente"
  )
    with_tempfiles([
      #["scarpe_log_config.json", JSON.dump(log_config_for_test)],
      [["shoes_spec_code", ".rb"], app_test_code],
    ]) do |shoes_spec_path,_|
      system(
        "LOCALAPPDATA=\"#{Dir.tmpdir}\" " +
        "SHOES_SPEC_TEST=\"#{shoes_spec_path}\" " +
        "SCARPE_DISPLAY_SERVICE=\"#{display_service}\" " +
        "SHOES_MINITEST_EXPORT_FILE=niente_test.json " +
        "SHOES_MINITEST_CLASS_NAME=\"#{class_name}\" " +
        "SHOES_MINITEST_METHOD_NAME=\"#{method_name}\" " +
        "ruby #{SCARPE_EXE} --dev #{test_app_location}"
      )
    end

    # Check if the process exited normally or crashed (segfault, failure, timeout)
    unless $?.success?
      assert(false, "Niente app failed with exit code: #{$?.exitstatus}")
      return
    end


  end
end
