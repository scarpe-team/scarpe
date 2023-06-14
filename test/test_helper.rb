# frozen_string_literal: true

RUBY_MAIN_OBJ = self

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "scarpe"

require "tempfile"
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

class ScarpeTest < Minitest::Test
  def with_tempfile(prefix, contents, dir: Dir.tmpdir)
    t = Tempfile.new(prefix, dir)
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
  LOGGER_DIR = File.expand_path("#{__dir__}/../logger")

  def run_test_scarpe_code(scarpe_app_code, test_code: "", **opts)
    bad_opts = opts.keys - TEST_OPTS
    raise "Bad options passed to run_test_scarpe_code: #{bad_opts.inspect}!" unless bad_opts.empty?

    with_tempfile("scarpe_test_app.rb", scarpe_app_code) do |test_app_location|
      run_test_scarpe_app(test_app_location, test_code:, **opts)
    end
  end

  def run_test_scarpe_app(test_app_location, test_code: "", **opts)
    bad_opts = opts.keys - TEST_OPTS
    raise "Bad options passed to run_test_scarpe_app: #{bad_opts.inspect}!" unless bad_opts.empty?

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

      # Remove old results, if any
      File.unlink(result_path)

      with_tempfile("scarpe_control.rb", scarpe_test_code) do |control_file_path|
        with_tempfile("scarpe_log_config.json", JSON.dump(log_config_for_test), dir: LOGGER_DIR) do |scarpe_log_config|
          # Start the application using the exe/scarpe utility
          system("SCARPE_TEST_CONTROL=#{control_file_path} SCARPE_TEST_RESULTS=#{result_path} " +
            "SCARPE_LOG_CONFIG=\"#{scarpe_log_config}\" " +
            "ruby #{SCARPE_EXE} --dev #{test_app_location}")

          # Check if the process exited normally or crashed (segfault, failure, timeout)
          unless $?.success?
            assert(false, "Scarpe app crashed with exit code: #{$?.exitstatus}")
            return
          end
        end
      end

      # If failure is okay, don't check for status or assertions
      return if opts[:allow_fail]

      # If we exit immediately with no result written, that's fine.
      # But if we wrote a result, make sure it says pass, not fail.
      return if opts[:exit_immediately] && !File.exist?(result_path)

      unless File.exist?(result_path)
        return assert(false, "Scarpe app returned no status code!")
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

          assert false, "App exited immediately, but its results were false! #{out_data.inspect}"
        end

        unless out_data[0]
          puts JSON.pretty_generate(out_data[1])
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
end

# This test will save extensive logs in case of test failure.
class LoggedScarpeTest < ScarpeTest
  def file_id
    "#{self.class.name}_#{self.name}"
  end

  def setup
    # Make sure test failures will be saved at the end of the run.
    # Delete stale test failures and logging only the *first* time this is called.
    set_up_test_failures

    @normal_log_config = Scarpe::Logger.current_log_config
    Scarpe::Logger.configure_logger(log_config_for_test)

    Scarpe::Logger.logger("LoggedScarpeTest").info("Test: #{self.class.name}##{self.name}")
  end

  def teardown
    # Restore previous log config
    Scarpe::Logger.configure_logger(@normal_log_config)

    if self.failure
      save_failure_logs
    else
      remove_unsaved_logs
    end
  end

  def log_config_for_test
    {
      "default" => ["debug", "logger/test_failure_#{file_id}.log"],
      "WebviewAPI" => ["debug", "logger/test_failure_wv_api_#{file_id}.log"],
    }
  end

  # This could be a lot simpler except I want to only update the file list in one place,
  # log_config_for_test(). Having a single spot should (I hope) make it a lot friendlier to
  # add more logfiles for different components, logged API objects, etc.
  def saved_log_files
    lc = log_config_for_test
    log_outfiles = lc.values.map { |_level, loc| loc }
    log_outfiles.select { |s| s.start_with?("logger/") }.map { |s| s.delete_prefix("logger/") }
  end

  # We want test failures set up once *total*, not per Minitest::Test. So an instance var
  # doesn't do it.
  ALREADY_SET_UP_TEST_FAILURES = { setup: false }

  def set_up_test_failures
    return if ALREADY_SET_UP_TEST_FAILURES[:setup]

    ALREADY_SET_UP_TEST_FAILURES[:setup] = true
    # Delete stale test failures, if any, before starting the first failure-logged test
    Dir["#{LOGGER_DIR}/test_failure*.log"].each { |fn| File.unlink(fn) }

    Minitest.after_run do
      # Print test failure notice to console
      unless Dir["#{LOGGER_DIR}/test_failure*.out.log"].empty?
        puts "Some tests have failed! See #{LOGGER_DIR}/test_failure*.out.log for test logs!"
      end

      # Remove un-saved test logs
      Dir["#{LOGGER_DIR}/test_failure*.log"].each do |f|
        next if f.include?(".out.log")

        File.unlink(f) if File.exist?(f)
      end
    end
  end

  def logfail_out_loc(filepath)
    # Add a .out prefix before final .log
    out_loc = filepath.gsub(%r{.log\Z}, ".out.log")

    if out_loc == filepath
      raise "Something is wrong! Could not figure out failure-log output path for #{filepath.inspect}!"
    end

    if File.exist?(out_loc)
      raise "Duplicate test name #{test_name.inspect}? This file should *not* already exist!"
    end

    out_loc
  end

  def save_failure_logs
    saved_log_files.each do |log_file|
      full_loc = File.expand_path("#{LOGGER_DIR}/#{log_file}")
      # TODO: we'd like to skip 0-length logfiles. But also Logging doesn't flush. For now, ignore.
      next unless File.exist?(full_loc)

      FileUtils.mv full_loc, logfail_out_loc(full_loc)
    end
  end

  def remove_unsaved_logs
    Dir["#{LOGGER_DIR}/test_failure*.log"].each do |f|
      next if f.include?(".out.log") # Don't delete saved logs

      File.unlink(f)
    end
  end
end
