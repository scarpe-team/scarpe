# frozen_string_literal: true

require "test_helper"

class TestPromises < Minitest::Test
  Promise = Scarpe::Promise
  #Promise.debug = true

  def empty_promise_with_checker(state: nil, parents: [])
    # Initially, no handlers have been called
    called = {
      fulfilled: false,
      rejected: false,
      scheduled: false,
    }
    p = Promise.new(state: state, parents: parents)
    p.on_fulfilled { called[:fulfilled] = true }
    p.on_rejected { called[:rejected] = true }
    p.on_scheduled { called[:scheduled] = true }

    [p, called]
  end

  def promise_that_immediately_returns(val, parents: [])
    Promise.fulfilled(val, parents: parents)
  end

  def test_simple_promise_fulfillment
    p, called = empty_promise_with_checker

    p.fulfilled!

    assert_equal true, called[:fulfilled], "Promise fulfilled handler wasn't called successfully on simple fulfillment!"
    assert_equal false, called[:rejected], "Promise rejection handler was called on simple fulfillment!"
    assert_equal true, called[:scheduled], "Promise scheduled handler wasn't called on simple fulfillment!"
  end

  def test_simple_promise_rejection
    p, called = empty_promise_with_checker

    p.rejected!

    assert_equal false, called[:fulfilled], "Promise wasn't called successfully on simple rejection!"
    assert_equal true, called[:rejected], "Promise rejection handler wasn't called on simple rejection!"

    # Here's a fun thing - the on_scheduled handler *will* be called, but only if there's no incomplete
    # parent, because effectively the promise will be scheduled during construction.
    assert_equal true, called[:scheduled], "Promise scheduled handler wasn't called on simple rejection!"
  end

  def test_dependent_promise_fulfillment
    parent_promise = Promise.new
    promise, called = empty_promise_with_checker(parents: [parent_promise])

    # If a promise has an incomplete parent, it will start as unscheduled
    assert_equal :unscheduled, promise.state
    assert_equal false, called[:scheduled]

    parent_promise.fulfilled!

    # After the parent is complete, it will be scheduled
    assert_equal :pending, promise.state
    assert_equal true, called[:scheduled]
  end

  def test_dependent_promise_rejection
    parent_promise = Promise.new
    promise, called = empty_promise_with_checker(parents: [parent_promise])

    # If a promise has an incomplete parent, it will start as unscheduled
    assert_equal :unscheduled, promise.state
    assert_equal false, called[:scheduled]

    parent_promise.rejected!

    # After the parent is rejected, it will be rejected
    assert_equal :rejected, promise.state
    assert_equal false, called[:scheduled]
    assert_equal true, called[:rejected]
  end

  def test_multiparent_fulfillment
    parent1_promise = Promise.new
    parent2_promise = Promise.new
    promise, called = empty_promise_with_checker(parents: [parent1_promise, parent2_promise])

    parent1_promise.fulfilled!

    assert_equal :unscheduled, promise.state
    assert_equal false, called[:scheduled]

    parent2_promise.fulfilled!

    # After the parents are complete, it will be scheduled
    assert_equal :pending, promise.state
    assert_equal true, called[:scheduled]
  end

  def test_multiparent_rejection
    parent1_promise = Promise.new
    parent2_promise = Promise.new
    promise, called = empty_promise_with_checker(parents: [parent1_promise, parent2_promise])

    parent1_promise.rejected!

    assert_equal :rejected, promise.state
    assert_equal false, called[:scheduled]
    assert_equal true, called[:rejected]
  end

  def test_instant_fulfillment
    p = promise_that_immediately_returns(7)
    assert_equal :fulfilled, p.state
    assert_equal 7, p.returned_value, "The promise should be fulfilled with a value of 7!"
  end

  def test_multiparent_instant_fulfillment_with_args
    parents = [
      promise_that_immediately_returns(7),
      promise_that_immediately_returns(5),
      promise_that_immediately_returns(8),
    ]
    assert_equal true, parents.all? { |p| p.complete? && p.returned_value.is_a?(Integer) }
    sum_up_promise = Promise.new(parents: parents)
    sum_up_promise.to_execute { |*args| args.sum }

    assert_equal :fulfilled, sum_up_promise.state
    assert_equal 20, sum_up_promise.returned_value
  end

  def test_multiparent_delayed_fulfillment_with_args
    parents = [
      Promise.new,
      promise_that_immediately_returns(10),
      Promise.new,
      Promise.new,
    ]
    sum_up_promise = Promise.new(parents: parents)
    sum_up_promise.to_execute { |*args| args.sum }

    parents[0].fulfilled!(3)
    parents[2].fulfilled!(8)

    assert_equal false, sum_up_promise.complete?

    parents[3].fulfilled!(9)

    assert_equal :fulfilled, sum_up_promise.state
    assert_equal 30, sum_up_promise.returned_value
  end

  def test_simple_executor_success
    p = Promise.new
    p.to_execute { 7 }

    assert_equal :fulfilled, p.state
    assert_equal 7, p.returned_value
  end

  def test_simple_executor_failure
    expected_err = RuntimeError.new "Yup, that's an error"
    p = Promise.new
    p.to_execute { raise expected_err }

    assert_equal :rejected, p.state
    assert_equal expected_err, p.reason
  end

  def test_delayed_executor_success
    parent = Promise.new
    p = Promise.new(parents: [parent])
    p.to_execute { 7 }

    assert_equal :unscheduled, p.state

    parent.fulfilled!

    assert_equal :fulfilled, p.state
    assert_equal 7, p.returned_value
  end

  def test_scheduler_raise_error
    expected_err = StandardError.new "Yup, that's an error"
    p = Promise.new { raise expected_err }

    assert_equal :rejected, p.state
    assert_equal expected_err, p.reason, "Promise should record the raised error as the reason for rejection!"
  end

  def test_explicit_rejected_error
    expected_err = StandardError.new "Yup, that's an error"
    p = Promise.new

    p.rejected!(expected_err)

    assert_equal expected_err, p.reason, "Promise should record the raised error as the reason for rejection!"
  end

  def test_then_with_success
    called = {
      p1_scheduled: false,
      p2_scheduled: false,
      p3_scheduled: false,
    }
    p1 = Promise.new { called[:p1_scheduled] = true }
    p1.then { called[:p2_scheduled] = true }.then { called[:p3_scheduled] = true }

    assert_equal true, called[:p1_scheduled]
    assert_equal false, called[:p2_scheduled]

    p1.fulfilled!

    assert_equal true, called[:p2_scheduled]
    assert_equal false, called[:p3_scheduled]
  end
end
