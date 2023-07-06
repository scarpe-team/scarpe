# frozen_string_literal: true

require "tempfile"
require "json"
require "fileutils"

module Scarpe::Test; end

# We want test failures set up once *total*, not per Minitest::Test. So an instance var
# doesn't do it.
ALREADY_SET_UP_LOGGED_TEST_FAILURES = { setup: false }

# General helpers for general usage
# Helpers here should *not* use Webview-specific functionality.
# The intention is that these are helpers for various Scarpe display
# services that do *not* use Webview.
module Scarpe::Test::Helpers
  def with_tempfile(prefix, contents, dir: Dir.tmpdir)
    t = Tempfile.new(prefix, dir)
    t.write(contents)
    t.flush # Make sure the contents are written out

    yield(t.path)
  ensure
    t.close
    t.unlink
  end

  # Pass an array of arrays, where each array is of the form:
  # [prefix, contents, (optional)dir]
  #
  # I don't love inlining with_tempfile's contents into here.
  # But calling it iteratively or recursively was difficult
  # when I tried it the obvious ways.
  def with_tempfiles(tf_specs, &block)
    tempfiles = []
    tf_specs.each do |prefix, contents, dir|
      dir ||= Dir.tmpdir
      t = Tempfile.new(prefix, dir)
      tempfiles << t
      t.write(contents)
      t.flush # Make sure the contents are written out
    end

    args = tempfiles.map(&:path)
    yield(args)
  ensure
    tempfiles.each do |t|
      t.close
      t.unlink
    end
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

  def assert_include(text, subtext, msg = nil)
    msg ||= "Expected #{text.inspect} to include #{subtext.inspect}"
    assert text.include?(subtext), msg
  end

  def assert_not_include(text, subtext, msg = nil)
    msg ||= "Expected #{text.inspect} not to include #{subtext.inspect}"
    assert !text.include?(subtext), msg
  end

  def assert_html(actual_html, expected_tag, **opts, &block)
    expected_html = Scarpe::HTML.render do |h|
      h.public_send(expected_tag, opts, &block)
    end

    assert_equal expected_html, actual_html
  end

  # This does a final return of results. If it gets called
  # multiple times, the test fails because that's not okay.
  def return_results(result_bool, msg, data = {})
    result_file = ENV["SCARPE_TEST_RESULTS"] || "./scarpe_results.txt"

    result_structs = [result_bool, msg, data.merge(test_metadata)]
    if File.exist?(result_file)
      results_returned = JSON.parse File.read(result_file)
    end

    # Multiple different sets of results is bad, even if both are passing.
    if results_returned && results_returned[0..1] != result_structs[0..1]
      # Just raising here doesn't reliably fail the test.
      # See: https://github.com/scarpe-team/scarpe/issues/212
      Scarpe::Logger.logger("Test Results").error("Writing multi-result failure file to #{result_file.inspect}!")

      new_res_data = { first_result: results_returned, second_result: result_structs }.merge(test_metadata)
      bad_result = [false, "Returned two sets of results!", new_res_data]
      File.write(result_file, JSON.pretty_generate(bad_result))

      return
    elsif results_returned
      Scarpe::Logger.logger("Test Results").warn "Returning identical results twice: #{results_returned.inspect}"
    end

    Scarpe::Logger.logger("Test Results").debug("Writing results file #{result_file.inspect} to disk!")
    File.write(result_file, JSON.pretty_generate(result_structs))
  end
end

# This test will save extensive logs in case of test failure.
# Note that it defines setup/teardown methods. If you want
# multiple setup/teardowns from multiple places to happen you
# may need to explictly call (e.g. with logged_test_setup/teardown)
# to ensure everything you want happens.
module Scarpe::Test::LoggedTest
  LOGGER_DIR = File.expand_path("#{__dir__}/../../logger")

  def file_id
    "#{self.class.name}_#{self.name}"
  end

  def logged_test_setup
    # Make sure test failures will be saved at the end of the run.
    # Delete stale test failures and logging only the *first* time this is called.
    set_up_test_failures

    @normal_log_config = Scarpe::Logger.current_log_config
    Scarpe::Logger.configure_logger(log_config_for_test)

    Scarpe::Logger.logger("LoggedScarpeTest").info("Test: #{self.class.name}##{self.name}")
  end

  # If you include this module and don't override setup/teardown, everything will
  # work fine. But if you need more setup/teardown steps, you can do that too.
  def setup
    logged_test_setup
  end

  def logged_test_teardown
    # Restore previous log config
    Scarpe::Logger.configure_logger(@normal_log_config)

    if self.failure
      save_failure_logs
    else
      remove_unsaved_logs
    end
  end

  def teardown
    logged_test_teardown
  end

  def log_config_for_test
    {
      "default" => ["debug", "logger/test_failure_#{file_id}.log"],

      "WebviewAPI" => ["debug", "logger/test_failure_wv_api_#{file_id}.log"],

      "CatsCradle" => ["debug", "logger/test_failure_catscradle_#{file_id}.log"],

      "DisplayService" => ["debug", "logger/test_failure_events_#{file_id}.log"],
      "WV::RelayDisplayService" => ["debug", "logger/test_failure_events_#{file_id}.log"],
      "WV::WebviewDisplayService" => ["debug", "logger/test_failure_events_#{file_id}.log"],
      "WV::ControlInterface" => ["debug", "logger/test_failure_events_#{file_id}.log"],
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

  def set_up_test_failures
    return if ALREADY_SET_UP_LOGGED_TEST_FAILURES[:setup]

    ALREADY_SET_UP_LOGGED_TEST_FAILURES[:setup] = true
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
      raise "Duplicate test file #{out_loc.inspect}? This file should *not* already exist!"
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
