# frozen_string_literal: true

RUBY_MAIN_OBJ = self

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "scarpe"
require "scarpe/unit_test_helpers"

require "json"
require "fileutils"

require "minitest/autorun"

require "minitest/reporters"
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

# Soon this should go in the framework, not here
unless Object.constants.include?(:Shoes)
  Shoes = Scarpe
end

# Docs for our Webview lib: https://github.com/Maaarcocr/webview_ruby

class ScarpeWebviewTest < Minitest::Test
  include Scarpe::Test::Helpers

  SCARPE_EXE = File.expand_path("../exe/scarpe", __dir__)

  def run_test_scarpe_code(
    scarpe_app_code,
    **opts
  )

    with_tempfile("scarpe_test_app.rb", scarpe_app_code) do |test_app_location|
      run_test_scarpe_app(test_app_location, **opts)
    end
  end

  def run_test_scarpe_app(
    test_app_location,
    test_code: "",
    timeout: 2.5,
    allow_fail: false,
    exit_immediately: false,
    display_service: "wv_local"
  )

    with_tempfile("scarpe_test_results.json", "") do |result_path|
      scarpe_test_code = <<~SCARPE_TEST_CODE
        require "scarpe/wv/control_interface_test"

        on_event(:init) do
          die_after #{timeout}
        end
      SCARPE_TEST_CODE

      scarpe_test_code += test_code

      if exit_immediately
        scarpe_test_code += <<~TEST_EXIT_IMMEDIATELY
          on_event(:next_heartbeat) do
            Scarpe::Logger.logger("ScarpeTest").info("Dying on heartbeat because :exit_immediately is set")
            app.destroy
          end
        TEST_EXIT_IMMEDIATELY
      end

      # Remove old results, if any
      File.unlink(result_path)

      with_tempfile("scarpe_control.rb", scarpe_test_code) do |control_file_path|
        with_tempfile("scarpe_log_config.json", JSON.dump(log_config_for_test)) do |scarpe_log_config|
          # Start the application using the exe/scarpe utility
          # For unit testing always supply --debug so we get the most logging
          system("SCARPE_TEST_CONTROL=#{control_file_path} SCARPE_TEST_RESULTS=#{result_path} " +
            "SCARPE_LOG_CONFIG=\"#{scarpe_log_config}\" " +
            "ruby #{SCARPE_EXE} --debug --dev #{test_app_location}")

          # Check if the process exited normally or crashed (segfault, failure, timeout)
          unless $?.success?
            assert(false, "Scarpe app failed with exit code: #{$?.exitstatus}")
            return
          end
        end
      end

      # If failure is okay, don't check for status or assertions
      return if allow_fail

      # If we exit immediately with no result written, that's fine.
      # But if we wrote a result, make sure it says pass, not fail.
      return if exit_immediately && !File.exist?(result_path)

      unless File.exist?(result_path)
        return assert(false, "Scarpe app returned no status code!")
      end

      out_data = JSON.parse File.read(result_path)
      Scarpe::Logger.logger("TestHelper").info("JSON assertion data: #{out_data.inspect}")

      unless out_data.respond_to?(:each) && out_data.length > 1
        raise "Scarpe app returned an unexpected data format! #{out_data.inspect}"
      end

      # If we exit immediately we still need a results file and a true value.
      # We were getting exit_immediately being fine with apps segfaulting,
      # so we need to check.
      if exit_immediately
        if out_data[0]
          # That's all we needed!
          return
        end

        assert false, "App exited immediately, but its results were false! #{out_data.inspect}"
      end

      unless out_data[0]
        puts JSON.pretty_generate(out_data[1..-1])
        assert false, "Some Scarpe tests failed..."
      end

      if out_data[1].is_a?(Hash)
        test_data = out_data[1]
        test_data["succeeded"].times { assert true } # Add to the number of assertions
        test_data["failures"].each { |failure| assert false, "Failed Scarpe app test: #{failure}" }
        if test_data["still_pending"] != 0
          assert false, "Some tests were still pending!"
        end
      end
    end
  end

  def assert_html(actual_html, expected_tag, **opts, &block)
    expected_html = Scarpe::HTML.render do |h|
      h.public_send(expected_tag, opts, &block)
    end

    assert_equal expected_html, actual_html
  end
end

class LoggedScarpeTest < ScarpeWebviewTest
  include Scarpe::Test::LoggedTest
end
