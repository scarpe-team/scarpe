# frozen_string_literal: true

require "tempfile"
require "json"
require "fileutils"

module Scarpe::Test; end

# We want test failures set up once *total*, not per Minitest::Test. So an instance var
# doesn't do it.
ALREADY_SET_UP_LOGGED_TEST_FAILURES = { setup: false }

# General helpers for general usage.
# Helpers here should *not* use Webview-specific functionality.
# The intention is that these are helpers for various Scarpe display
# services that do *not* necessarily use Webview.
module Scarpe::Test::Helpers
  # Create a temporary file with the given prefix and contents.
  # Execute the block of code with it in place. Make sure
  # it gets cleaned up afterward.
  #
  # @param prefix [String] the prefix passed to Tempfile to identify this file on disk
  # @param contents [String] the file contents that should be written to Tempfile
  # @param dir [String] the directory to create the tempfile in
  # @yield The code to execute with the tempfile present
  # @yieldparam the path of the new tempfile
  def with_tempfile(prefix, contents, dir: Dir.tmpdir)
    t = Tempfile.new(prefix, dir)
    t.write(contents)
    t.flush # Make sure the contents are written out

    yield(t.path)
  ensure
    t.close
    t.unlink
  end

  # Create multiple tempfiles, with given contents, in given
  # directories, and execute the block in that context.
  # When the block is finished, make sure all tempfiles are
  # deleted.
  #
  # Pass an array of arrays, where each array is of the form:
  # [prefix, contents, (optional)dir]
  #
  # I don't love inlining with_tempfile's contents into here.
  # But calling it iteratively or recursively was difficult
  # when I tried it the obvious ways.
  #
  # This method should be equivalent to calling with_tempfile
  # once for each entry in the array, in a set of nested
  # blocks.
  #
  # @param tf_specs [Array<Array>] The array of tempfile prefixes, contents and directories
  # @yield The code to execute with those tempfiles present
  # @yieldparam An array of paths to tempfiles, in the same order as tf_specs
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

  # Temporarily set env vars for the block of code inside. The old environment
  # variable values will be restored after the block finishes.
  #
  # @param envs [Hash<String,String>] A hash of environment variable names and values
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

  # Assert that `text` includes `subtext`.
  #
  # @param text [String] the longer text
  # @param subtext [String] the text that is asserted to be included
  # @param msg [String,nil] if supplied, the failure message for the assertion
  # @return [void]
  def assert_include(text, subtext, msg = nil)
    msg ||= "Expected #{text.inspect} to include #{subtext.inspect}"
    assert text.include?(subtext), msg
  end

  # Assert that `text` does not include `subtext`.
  #
  # @param text [String] the longer text
  # @param subtext [String] the text that is asserted to not be included
  # @param msg [String,nil] if supplied, the failure message for the assertion
  # @return [void]
  def assert_not_include(text, subtext, msg = nil)
    msg ||= "Expected #{text.inspect} not to include #{subtext.inspect}"
    assert !text.include?(subtext), msg
  end

  # Assert that `actual_html` is the same as `expected_tag` with `opts`.
  # This uses Scarpe's HTML tag-based renderer to render the tag and options
  # into text, and valides that the text is the same.
  #
  # @see Scarpe::HTML.render
  #
  # @param actual_html [String] the html to compare to
  # @param expected_tag [String,Symbol] the HTML tag, used to send a method call
  # @param opts keyword options passed to the tag method call
  # @yield block passed to the tag method call.
  # @return [void]
  def assert_html(actual_html, expected_tag, **opts, &block)
    expected_html = Scarpe::HTML.render do |h|
      h.public_send(expected_tag, opts, &block)
    end

    assert_equal expected_html, actual_html
  end

  # This does a final return of results. If it gets called
  # multiple times, the test fails because that's not allowed.
  #
  # @param result_bool [Boolean] true if the results are success, false if failure
  # @param msg [String] the message included with the results
  # @param data [Hash] any additional data to pass with the results
  # @return void
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
      Shoes::Log.logger("Test Results").error("Writing multi-result failure file to #{result_file.inspect}!")

      new_res_data = { first_result: results_returned, second_result: result_structs }.merge(test_metadata)
      bad_result = [false, "Returned two sets of results!", new_res_data]
      File.write(result_file, JSON.pretty_generate(bad_result))

      return
    elsif results_returned
      Shoes::Log.logger("Test Results").warn "Returning identical results twice: #{results_returned.inspect}"
    end

    Shoes::Log.logger("Test Results").debug("Writing results file #{result_file.inspect} to disk!")
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

  private

  def file_id
    "#{self.class.name}_#{self.name}"
  end

  public

  # This should be called by the test during setup to make sure that
  # failure logs will be saved if this test fails. It makes sure the
  # log config will save all logs from all sources, but keeps a copy
  # of the old log config to restore after the test is finished.
  #
  # @return [void]
  def logged_test_setup
    # Make sure test failures will be saved at the end of the run.
    # Delete stale test failures and logging only the *first* time this is called.
    set_up_test_failures

    @normal_log_config = Shoes::Log.current_log_config
    Shoes::Log.configure_logger(log_config_for_test)

    Shoes::Log.logger("LoggedScarpeTest").info("Test: #{self.class.name}##{self.name}")
  end

  # If you include this module and don't override setup/teardown, everything will
  # work fine. But if you need more setup/teardown steps, you can do that too.
  #
  # The setup method guarantees that just including this module will do setup
  # automatically. If you override it, be sure to call `super` or `logged_test_setup`.
  #
  # @return [void]
  def setup
    logged_test_setup
  end

  # After the test has finished, this will restore the old log configuration.
  # It will also save the logfiles, but only if the test failed, not if it
  # succeeded or was skipped.
  #
  # @return [void]
  def logged_test_teardown
    # Restore previous log config
    Shoes::Log.configure_logger(@normal_log_config)

    if self.failure
      save_failure_logs
    else
      remove_unsaved_logs
    end
  end

  # Make sure that, by default, #logged_test_teardown will be called for teardown.
  # If a class overrides teardown, it should also call `super` or `logged_test_teardown`
  # to make sure this still happens.
  #
  # @return [void]
  def teardown
    logged_test_teardown
  end

  # This is the log config that LoggedTests use. It makes sure all components keep all
  # logs, but also splits the logs into several different files for later ease of scanning.
  #
  # @return [Hash] the log config
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

  # The list of logfiles that should be saved. Normally this is called internally by the
  # class, not externally from elsewhere.
  #
  # This could be a lot simpler except I want to only update the file list in one place,
  # log_config_for_test(). Having a single spot should (I hope) make it a lot friendlier to
  # add more logfiles for different components, logged API objects, etc.
  def saved_log_files
    lc = log_config_for_test
    log_outfiles = lc.values.map { |_level, loc| loc }
    log_outfiles.select { |s| s.start_with?("logger/") }.map { |s| s.delete_prefix("logger/") }
  end

  # Make sure that test failure logs will be noticed, and a message will be printed,
  # if any logged tests fail. This needs to be called at least once in any Minitest-enabled
  # process using logged tests.
  #
  # @return [void]
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

  # Failure log output location for a given file path. This is normally used internally to this
  # class, not externally.
  #
  # @return [String] the output path
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

  # Save the failure logs in the appropriate place(s). This is normally used internally, not externally.
  #
  # @return [void]
  def save_failure_logs
    saved_log_files.each do |log_file|
      full_loc = File.expand_path("#{LOGGER_DIR}/#{log_file}")
      # TODO: we'd like to skip 0-length logfiles. But also Logging doesn't flush. For now, ignore.
      next unless File.exist?(full_loc)

      FileUtils.mv full_loc, logfail_out_loc(full_loc)
    end
  end

  # Remove unsaved failure logs. This is normally used internally, not externally.
  #
  # @return [void]
  def remove_unsaved_logs
    Dir["#{LOGGER_DIR}/test_failure*.log"].each do |f|
      next if f.include?(".out.log") # Don't delete saved logs

      File.unlink(f)
    end
  end
end
