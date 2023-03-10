# frozen_string_literal: true

RUBY_MAIN_OBJ = self

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "scarpe"

require "tempfile"
require "json"

require "minitest/autorun"

# We're going to be passing a fair bit of data back and forth across eval boundaries.
TEST_DATA = {}

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

# Temporarily set env vars for the block of code inside
def with_env_vars(envs)
  old_env = {}
  envs.each { |k, v| old_env[k] = ENV[k]; ENV[k] = v }
  yield
ensure
  old_env.each { |k, v| ENV[k] = v }
end

SCARPE_EXE = File.expand_path("../exe/scarpe", __dir__)
TEST_OPTS = [:timeout, :allow_fail, :debug, :exit_immediately]

def test_scarpe_code(scarpe_app_code, test_code: "", **opts)
  bad_opts = opts.keys - TEST_OPTS
  raise "Bad options passed to test_scarpe_code: #{bad_opts.inspect}!" unless bad_opts.empty?

  with_tempfile("scarpe_test_app.rb", scarpe_app_code) do |test_app_location|
    test_scarpe_app(test_app_location, test_code: test_code, **opts)
  end
end

def test_scarpe_app(test_app_location, test_code: "", **opts)
  bad_opts = opts.keys - TEST_OPTS
  raise "Bad options passed to test_scarpe_app: #{bad_opts.inspect}!" unless bad_opts.empty?

  with_tempfile("scarpe_test_results.json", "") do |result_path|
    do_debug = opts[:debug] ? true : false
    die_after = opts[:timeout] ? opts[:timeout].to_f : 1.5
    scarpe_test_code = <<~SCARPE_TEST_CODE
      override_app_opts debug: #{do_debug}

      on_event(:init) do
        t_start = Time.now
        wrangler.periodic_code("scarpePeriodicCallback", 0.1) do |*_args|
          if ((Time.now - t_start).to_f > #{die_after})
            app.destroy
          end
        end

        result_file = #{result_path.inspect}
        wrangler.bind("scarpeStatusAndExit") do |*results|
          puts "Writing results file \#{result_file.inspect} to disk!" if #{do_debug}
          File.open(result_file, "w") { |f| f.write(JSON.pretty_generate(results)) }
          app.destroy
        end
      end
    SCARPE_TEST_CODE

    if opts[:exit_immediately]
      scarpe_test_code += <<~TEST_EXIT_IMMEDIATELY
        on_event(:frame) do
          js_eval "scarpeStatusAndExit(true);"
        end
      TEST_EXIT_IMMEDIATELY
    end

    scarpe_test_code += test_code

    # No results until we write them
    File.unlink(result_path)

    with_tempfile("scarpe_control.rb", scarpe_test_code) do |control_file_path|
      # Start the application using the exe/scarpe utility
      system("SCARPE_TEST_CONTROL=#{control_file_path} ruby #{SCARPE_EXE} --dev #{test_app_location}")
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

# This doesn't have to happen in a different process...
def test_scarpe_code_no_display(app_code, test_code_str, **opts)
  with_env_vars("SCARPE_DISPLAY_SERVICES" => "-") do
    test_code = proc do |app|
      class << app
        include ::Scarpe::DisplayService::LinkableTest
        include ::Scarpe::AppTest
      end
      app.instance_eval test_code_str
    end
    Scarpe::App.next_test_code = test_code
    RUBY_MAIN_OBJ.send(:eval, app_code)
  end
end
