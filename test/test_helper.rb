# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "scarpe"

require "tempfile"
require "json"

require "minitest/autorun"

# Docs for our Webview lib: https://github.com/Maaarcocr/webview_ruby

SCARPE_EXE = File.expand_path("../exe/scarpe", __dir__)

TEST_OPTS = [:timeout, :allow_fail, :debug]
def test_scarpe_app(body_code, opts = {})
  bad_opts = opts.keys - TEST_OPTS
  raise "Bad options passed to test_scarpe_app: #{bad_opts.inspect}!" unless bad_opts.empty?

  out = Tempfile.new("scarpe_test_results.json")
  out_path = File.expand_path out.path
  Tempfile.open("scarpe_test") do |f|
    do_debug = opts[:debug] ? true : false
    die_after = opts[:timeout] ? opts[:timeout].to_f : 1.0
    f.write(
      "Scarpe.app(test_assertions: true, debug:#{do_debug.inspect}, die_after: #{die_after}, " \
        "result_filename: #{out_path.inspect}) do\n",
    )
    f.write(body_code)
    f.write("\nend\n")
    f.flush # Make sure the code is written out

    script_location = File.expand_path(f.path)
    system("ruby #{SCARPE_EXE} --dev #{script_location}")
    f.unlink
  end

  # If failure is okay, don't check for status or assertions
  return if opts[:allow_fail]

  unless File.exist?(out_path)
    assert(false, "Scarpe app returned no status code!")
    return
  end

  begin
    out_data = JSON.parse File.read(out_path)
    begin
      out.unlink
    rescue
      nil
    end # Probably never written

    assert(
      out_data.respond_to?(:each) && out_data[0],
      "Scarpe app returned a non-Arrayish or non-truthy status! #{out_data.inspect}",
    )
  rescue
    $stderr.puts "Error parsing JSON data for Scarpe test status!"
    raise
  end
end

def assert_html(actual_html, expected_tag, **opts, &block)
  expected_html = Scarpe::HTML.render do |h|
    h.public_send(expected_tag, opts, &block)
  end

  assert_equal expected_html, actual_html
end
