# frozen_string_literal: true

# The ControlInterface doesn't, by default, include much of a test framework.
# But writing a test framework in heredocs in test_helper.rb seems bad.
# So we write a test framework here, but don't include it by default.
# A running shoes app won't normally include it, but unit tests will.

require "json"

class Scarpe
  DEFAULT_ASSERTION_TIMEOUT = 1.0

  class ControlInterface
    include Scarpe::Test::Helpers

    def timed_out?
      @did_time_out
    end

    def die_after(time)
      t_start = Time.now
      @die_after = [t_start, time]

      wrangler.periodic_code("scarpeTestTimeout") do |*_args|
        t_delta = (Time.now - t_start).to_f
        if t_delta > time
          @did_time_out = true
          @log.warn("die_after - timed out after #{t_delta.inspect} (threshold: #{time.inspect})")
          return_results(false, "Timed out!")
          app.destroy
        end
      end
    end

    # This is returned alongside the actual results automatically
    def test_metadata
      data = {}
      if @die_after
        t_delta = (Time.now - @die_after[0]).to_f
        data["die_after"] = {
          t_start: @die_after[0].to_s,
          threshold: @die_after[1],
          passed: t_delta,
        }
      end
      data
    end

    # Need to be able to query widgets in test code

    def all_wv_widgets
      known = [doc_root]
      to_check = [doc_root]

      until to_check.empty?
        next_layer = to_check.flat_map(&:children)
        known += next_layer
        to_check = next_layer
      end

      # I don't *think* we'll ever have widget trees that merge back together, but just in case we'll de-dup
      known.uniq
    end

    # Shoes doesn't name widgets. We aren't guaranteed that the Shoes widgets are even in the same
    # process, since we have the Relay display service for Webview. So mostly we can look by
    # display service class.
    def find_wv_widgets(*specifiers)
      widgets = all_wv_widgets

      specifiers.each do |spec|
        if spec.is_a?(Class)
          widgets.select! { |w| spec === w }
        else
          raise "I don't know how to search for widgets by #{spec.inspect}!"
        end
      end

      widgets
    end

    # We want an assertions library, but one that runs inside the spawned
    # Webview sub-process.

    # Note that we do *not* extract this assertions library to use elsewhere
    # because it's very focused on evented assertions that start and stop
    # over a period of time. Instantaneous procedural asserts don't want to
    # use this API.

    def return_when_assertions_done
      assertions_may_exist

      wrangler.periodic_code("scarpeReturnWhenAssertionsDone") do |*_args|
        if @assertions_pending.empty?
          success = @assertions_failed.empty?
          return_results success, "Assertions #{success ? "succeeded" : "failed"}", assertion_data_as_a_struct
          app.destroy
        end
      end
    end

    def assertions_may_exist
      @assertions_pending ||= {}
      @assertions_failed ||= {}
      @assertions_passed ||= 0
      @assertion_counter ||= 0
    end

    def start_assertion(code)
      assertions_may_exist

      this_assertion = @assertion_counter
      @assertion_counter += 1

      @assertions_pending[this_assertion] = {
        id: this_assertion,
        code: code,
      }

      this_assertion
    end

    def pass_assertion(id)
      @assertions_pending.delete(id)
      @assertions_passed += 1
    end

    def fail_assertion(id, fail_message)
      item = @assertions_pending.delete(id)
      item[:fail_message] = fail_message
      @assertions_failed[id] = item
    end

    def assertions_pending?
      !@assertions_pending.empty?
    end

    def assertion_data_as_a_struct
      {
        still_pending: @assertions_pending.size,
        succeeded: @assertions_passed,
        failed: @assertions_failed.size,
        failures: @assertions_failed.values.map { |item| [item[:code], item[:failure_reason]] },
      }
    end

    # Create a promise to do a JS assertion, normally after other ops have finished.
    def assert_js(js_code, wait_for: [], timeout: DEFAULT_ASSERTION_TIMEOUT)
      id = start_assertion(js_code)

      # this isn't a TestPromise, so it doesn't have the additional DSL entries
      promise = wrangler.eval_js_async(js_code, wait_for: wait_for, timeout: timeout)
      promise.on_rejected do
        fail_assertion(id, "JS Eval failed: #{promise.reason.inspect}")
      end
      promise.on_fulfilled do
        ret_val = promise.returned_value
        if ret_val
          pass_assertion(id)
        else
          fail_assertion(id, "Expected true JS value: #{ret_val.inspect}")
        end
      end

      # So we wrap it in a no-op TestPromise, to get the DSL entries.
      TestPromise.new(iface: self, wait_for: [promise]).to_execute {}
    end

    def assert(value, msg = nil)
      id = start_assertion("#{caller[0]}: #{msg || "Value should be true!"}")

      if value
        pass_assertion(id)
      else
        fail_assertion(id, "Expected true Ruby value: #{value.inspect}")
      end
    end

    def assert_equal(val1, val2, msg = nil)
      assert val1 == val2, (msg || "Expected #{val2.inspect} to equal #{val1.inspect}!")
    end

    # How do we signal an error?
    def with_js_value(js_code, wait_for: [], timeout: DEFAULT_ASSERTION_TIMEOUT, &block)
      raise "Must give a block to with_js_value!" unless block

      js_promise = wrangler.eval_js_async(js_code, wait_for: wait_for, timeout: timeout)
      ruby_promise = TestPromise.new(iface: self, wait_for: [js_promise])
      ruby_promise.to_execute(&block)
      ruby_promise
    end

    def with_js_dom_html(wait_for: [], timeout: DEFAULT_ASSERTION_TIMEOUT, &block)
      with_js_value("document.getElementById('wrapper-wvroot').innerHTML", wait_for: wait_for, timeout: timeout, &block)
    end

    def fully_updated(wait_for: [])
      wrangler.promise_dom_fully_updated
    end
  end

  # A Promise but with helper functions
  class TestPromise < Promise
    def initialize(iface:, state: nil, wait_for: [], &scheduler)
      @iface = iface
      super(state: state, parents: wait_for, &scheduler)
    end

    def inspect
      "<#TestPromise::#{object_id} state=#{state.inspect} parents=#{parents.inspect} value=#{returned_value.inspect} reason=#{reason.inspect}>"
    end

    # This method expects to wait for the parent TestPromise and then run a block of Ruby that returns
    # another promise. This is useful for wrapping Promises like those from replace() that don't have
    # the test DSL built in. The block will execute when this outer promise is scheduled -- so we don't do
    # a replace() too early, for instance. And then the outer promise will fulfill when the inner one does.
    def then_ruby_promise(wait_for: [], &block)
      ruby_wrapper_promise = TestPromise.new iface: @iface, wait_for: ([self] + wait_for)

      ruby_wrapper_promise.on_scheduled do
        inner_ruby_promise = block.call
        inner_ruby_promise.on_fulfilled { ruby_wrapper_promise.fulfilled!(inner_ruby_promise.returned_value) }
      end
    end

    def then_with_js_value(js_code, wait_for: [], timeout: DEFAULT_ASSERTION_TIMEOUT, &block)
      @iface.with_js_value(js_code, wait_for: (wait_for + [self]), timeout:, &block)
    end

    def then_with_js_dom_html(wait_for: [], timeout: DEFAULT_ASSERTION_TIMEOUT, &block)
      @iface.with_js_dom_html(wait_for: (wait_for + [self]), timeout:, &block)
    end
  end
end
