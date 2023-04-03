# frozen_string_literal: true

RUBY_MAIN_OBJ = self

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "scarpe"

require "tempfile"
require "json"

require "minitest/autorun"

require "minitest/reporters"
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

# We're going to be passing a fair bit of data back and forth across eval boundaries.
TEST_DATA = {}

# Soon this should go in the framework, not here
unless Object.constants.include?(:Shoes)
  Shoes = Scarpe
end

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
  envs.each do |k, v|
    old_env[k] = ENV[k]
    ENV[k] = v
  end
  yield
ensure
  old_env.each { |k, v| ENV[k] = v }
end

SCARPE_EXE = File.expand_path("../exe/scarpe", __dir__)
TEST_OPTS = [:timeout, :allow_fail, :allow_timeout, :debug, :exit_immediately]

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
    timeout = opts[:timeout] ? opts[:timeout].to_f : 1.5
    scarpe_test_code = <<~SCARPE_TEST_CODE
      require "scarpe/wv/control_interface_test"

      override_app_opts debug: #{do_debug}

      on_event(:init) do
        die_after #{timeout}

        # scarpeStatusAndExit is barbaric, and ignores all pending assertions and other subtleties.
        wrangler.bind("scarpeStatusAndExit") do |*results|
          return_results(results)
          app.destroy
        end
      end
    SCARPE_TEST_CODE

    scarpe_test_code += test_code

    if opts[:exit_immediately]
      scarpe_test_code += <<~TEST_EXIT_IMMEDIATELY
        on_event(:next_heartbeat) do
          app.destroy
        end
      TEST_EXIT_IMMEDIATELY
    end

    # No results until we write them
    File.unlink(result_path)

    with_tempfile("scarpe_control.rb", scarpe_test_code) do |control_file_path|
      # Start the application using the exe/scarpe utility
      system("SCARPE_TEST_CONTROL=#{control_file_path} SCARPE_TEST_RESULTS=#{result_path} " +
        "ruby #{SCARPE_EXE} --dev #{test_app_location}")

      # Check if the process exited normally or crashed (segfault)
      if $?.exitstatus != 0
        assert(false, "Scarpe app crashed with exit code: #{$?.exitstatus}")
        return
      end
    end

    # If failure is okay, don't check for status or assertions
    return if opts[:allow_fail]

    # If we exit immediately with no result written, that's fine.
    # But if we wrote a result, make sure it says pass, not fail.
    return if opts[:exit_immediately] && !File.exist?(result_path)

    unless File.exist?(result_path)
      assert(false, "Scarpe app returned no status code!")
      return
    end

    begin
      out_data = JSON.parse File.read(result_path)

      unless out_data.respond_to?(:each) && out_data.length > 1
        raise "Scarpe app returned an unexpected data format! #{out_data.inspect}"
      end

      # If we exit immediately we still need a results file and a true value.
      # We were getting exit_immediately being fine with apps segfaulting,
      # so we need to check.
      if opts[:exit_immediately]
        if out_data[0]
          # That's all we needed!
          return
        end

        assert false, "App exited immediately, but its results were false! #{out_data.inspect}  App: #{test_app_location}"
      end

      unless out_data[0]
        puts JSON.pretty_generate(out_data[1])
        assert false, "Some Scarpe tests failed..."
      end

      if out_data[1].is_a?(Hash)
        test_data = out_data[1]
        test_data["succeeded"].times { assert true } # Add to the number of assertions
        test_data["failures"].each { |failure| assert false, "Failed Scarpe app test: #{failure}" }
        assert_equal 0, test_data["still_pending"], "Some tests were still pending!"
      end
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
