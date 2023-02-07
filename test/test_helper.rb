# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "scarpe"

require "tempfile"
require "json"

require "minitest/autorun"

# Docs for our Webview lib: https://github.com/Maaarcocr/webview_ruby

SCARPE_EXE = File.expand_path("../exe/scarpe", __dir__)

def test_scarpe_app(body_code)
  out = Tempfile.new("scarpe_test_results.json")
  out_path = File.expand_path out.path
  Tempfile.open("scarpe_test") do |f|
    f.write("Scarpe.app(debug:true, die_after: 1.0, result_filename: #{out_path.inspect}) do\n")
    f.write(body_code)
    f.write("\nend\n")
    f.flush # Make sure the code is written out

    script_location = File.expand_path(f.path)
    system("ruby #{SCARPE_EXE} --dev #{script_location}")
    f.unlink
  end

  unless File.exist?(out_path)
    assert(false, "Scarpe app returned no status code!")
    return
  end

  begin
    out_data = JSON.load File.read(out_path)
    out.unlink rescue nil # Probably never written

    assert(out_data.respond_to?(:each) && out_data[0], "Scarpe app returned a non-Arrayish or non-truthy status! #{out_data.inspect}")
  rescue
    STDERR.puts "Error parsing JSON data for Scarpe test status!"
    raise
  end
end
