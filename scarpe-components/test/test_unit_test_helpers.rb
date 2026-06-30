# frozen_string_literal: true

require_relative "test_helper"

require "tmpdir"

class DummyLoggedTest
  include Scarpe::Test::LoggedTest

  class << self
    attr_accessor :logger_dir
  end
end

class TestUnitTestHelpers < Minitest::Test
  def setup
    @logger_dir = Dir.mktmpdir("logged-test-cleanup")
    DummyLoggedTest.logger_dir = @logger_dir
    ALREADY_SET_UP_LOGGED_TEST_FAILURES[:setup] = false
  end

  def teardown
    ALREADY_SET_UP_LOGGED_TEST_FAILURES[:setup] = false
    FileUtils.remove_entry(@logger_dir) if File.directory?(@logger_dir)
  end

  def test_logged_test_setup_ignores_stale_glob_entries
    File.write(File.join(@logger_dir, "test_failure_demo.log"), "demo")

    with_stale_globbed_log_paths do
      DummyLoggedTest.new.send(:set_up_test_failures)
    end

    assert ALREADY_SET_UP_LOGGED_TEST_FAILURES[:setup]
  end

  def test_remove_unsaved_logs_ignores_stale_glob_entries
    File.write(File.join(@logger_dir, "test_failure_demo.log"), "demo")

    with_stale_globbed_log_paths do
      DummyLoggedTest.new.send(:remove_unsaved_logs)
    end

    assert_empty Dir["#{@logger_dir}/test_failure*.log"]
  end

  private

  def with_stale_globbed_log_paths
    dir_singleton = class << Dir
      self
    end
    original = Dir.method(:[])

    dir_singleton.send(:define_method, :[]) do |pattern|
      results = original.call(pattern)
      results.each { |f| FileUtils.rm_f(f) }
      results
    end

    yield
  ensure
    dir_singleton.send(:define_method, :[], original)
  end
end
