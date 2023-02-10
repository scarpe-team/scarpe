# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "scarpe"

require "tempfile"
require "json"

require "minitest/autorun"

# Docs for our Webview lib: https://github.com/Maaarcocr/webview_ruby

def with_tempfile(prefix, contents)
  t = Tempfile.new(prefix)
  t.write(contents)
  t.flush # Make sure the contents are written out

  yield(t.path)
ensure
  t.close
  t.unlink
end

SCARPE_EXE = File.expand_path("../exe/scarpe", __dir__)
TEST_OPTS = [:timeout, :allow_fail, :debug, :exit_immediately]
def test_scarpe_app(body_code, test_code: "", **opts)
  bad_opts = opts.keys - TEST_OPTS
  raise "Bad options passed to test_scarpe_app: #{bad_opts.inspect}!" unless bad_opts.empty?

  do_debug = opts[:debug] ? true : false
  die_after = opts[:timeout] ? opts[:timeout].to_f : 1.0
  scarpe_app_code = <<~SCARPE_APP_CODE
    Scarpe.app do
      #{body_code}
    end
  SCARPE_APP_CODE

  with_tempfile("scarpe_test_results.json", "") do |result_path|
    scarpe_test_code = <<~SCARPE_TEST_CODE
      override_app_opts test_assertions: true, debug: #{do_debug}, die_after: #{die_after}, result_filename: #{result_path.inspect}
    SCARPE_TEST_CODE
    if opts[:exit_immediately]
      scarpe_test_code += <<~TEST_EXIT_IMMEDIATELY
        on_event(:frame) {
          js_eval "scarpeStatusAndExit(true);"
        }
      TEST_EXIT_IMMEDIATELY
    end
    scarpe_test_code += test_code

    with_tempfile("scarpe_test.rb", scarpe_app_code) do |shoes_app_location|
      with_tempfile("scarpe_control.rb", scarpe_test_code) do |control_file_path|
        system("SCARPE_TEST_CONTROL=#{control_file_path} ruby #{SCARPE_EXE} --dev #{shoes_app_location}")
      end
    end

    # If failure is okay, don't check for status or assertions
    return if opts[:allow_fail]

    unless File.exist?(result_path)
      assert(false, "Scarpe app returned no status code!")
      return
    end

    begin
      out_data = JSON.parse File.read(result_path)

      assert(
        out_data.respond_to?(:each) && out_data[0],
        "Scarpe app returned a non-Arrayish or non-truthy status! #{out_data.inspect}",
      )
    rescue
      $stderr.puts "Error parsing JSON data for Scarpe test status!"
      raise
    end
  end
end

def assert_html(actual_html, expected_tag, **opts, &block)
  expected_html = Scarpe::HTML.render do |h|
    h.public_send(expected_tag, opts, &block)
  end

  assert_equal expected_html, actual_html
end
