# frozen_string_literal: true

require_relative "test_helper"

require "scarpe/components/minitest_result"

class TestMinitestResult < Minitest::Test
  def test_mtr_success
    path = File.join __dir__, "mtr_data/succeed_2_asserts.json"
    res = Scarpe::Components::MinitestResult.new(path)

    refute res.error?
    refute res.fail?
    refute res.skip?
    assert res.passed?, "Passing result with two assertions should count as passing!"
    assert_equal 2, res.assertions
  end

  def test_mtr_failure
    path = File.join __dir__, "mtr_data/fail_with_message.json"
    res = Scarpe::Components::MinitestResult.new(path)

    refute res.error?, "Fail-with-message data should not be an error!"
    assert res.fail?, "Fail-with-message data should be a failure!"
    refute res.skip?
    refute res.passed?
    assert_equal "Fail with message", res.fail_message
  end

  def test_mtr_error
    path = File.join __dir__, "mtr_data/exception.json"
    res = Scarpe::Components::MinitestResult.new(path)

    assert res.error?, "Exception data should show an error!"
    refute res.fail?, "Exception data should not be an assertion failure!"
    refute res.skip?
    refute res.passed?
    assert res.error_message.include?("This is an exception"), "Error msg data should include the exception message"
  end

  def test_mtr_skip_no_msg
    path = File.join __dir__, "mtr_data/skipped_no_message.json"
    res = Scarpe::Components::MinitestResult.new(path)

    refute res.error?, "Skipped data should not be an error!"
    refute res.fail?, "Skipped data should not be a failure!"
    assert res.skip?, "Skipped data should count as skipped"
    refute res.passed?
  end

  def test_mtr_skip_w_msg
    path = File.join __dir__, "mtr_data/skipped_w_msg.json"
    res = Scarpe::Components::MinitestResult.new(path)

    refute res.error?, "Skipped data should not be an error!"
    refute res.fail?, "Skipped data should not be a failure!"
    assert res.skip?, "Skipped data should count as skipped"
    refute res.passed?
    assert_equal "Just skipping", res.skip_message
  end
end
