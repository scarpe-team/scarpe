# The ControlInterface doesn't, by default, include much of a test framework.
# But writing a test framework in heredocs in test_helper.rb seems bad.
# So we write a test framework here, but don't include it by default.
# A running shoes app won't normally include it, but unit tests will.

require "json"

class Scarpe
  DEFAULT_ASSERTION_TIMEOUT = 1.0

  class ControlInterface
    def timed_out?
      @did_time_out
    end

    def die_after(time)
      t_start = Time.now

      wrangler.periodic_code("scarpeTestTimeout") do |*_args|
        if (Time.now - t_start).to_f > time
          @did_time_out = true
          app.destroy
        end
      end
    end

    def return_when_assertions_done
      assertions_may_exist

      wrangler.periodic_code("scarpeReturnWhenAssertionsDone") do |*_args|
        if @assertions_pending.empty?
          success = @assertions_failed.empty?
          return_results [success, assertion_data_as_a_struct]
          app.destroy
        end
      end
    end

    # This does a final return of results. Don't call it yourself
    # unless you want any other results that would be returned
    # to be wiped out.
    def return_results(result_structs)
      if @results_returned
        raise "Returning more than one set of results! Bad!"
      end

      result_file = ENV['SCARPE_TEST_RESULTS'] || "./scarpe_results.txt"
      puts "Writing results file #{result_file.inspect} to disk!" if @debug
      File.open(result_file, "w") { |f| f.write(JSON.pretty_generate(result_structs)); f.flush }

      @results_returned = true
    end

    private

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

    def fail_assertion(id)
      item = @assertions_pending.delete(id)
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
        failures: @assertions_failed.values.map { |item| item[:code] },
      }
    end

    public

    def all_widgets
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

    # Shoes doesn't name widgets. I don't know if we can get at instance variables.
    def find_widgets(*specifiers)
      widgets = all_widgets

      specifiers.each do |spec|
        if spec.is_a?(Class)
          widgets.select! { |w| spec === w }
        else
          raise "I don't know how to search for widgets by #{spec.inspect}!"
        end
      end

      widgets
    end

    # Create a promise to do a JS assertion, normally after other ops have finished.
    def assert_js(js_code, wait_for: [], timeout: DEFAULT_ASSERTION_TIMEOUT)
      id = start_assertion(js_code)

      # Note: this isn't a TestPromise, so it doesn't have the additional DSL entries...
      promise = wrangler.eval_js_async(js_code, wait_for: wait_for, timeout: timeout)
      promise.on_rejected {
        fail_assertion(id)
      }
      promise.on_fulfilled {
        pass_assertion(id)
      }

      # So we wrap it in a no-op TestPromise, to get the DSL entries.
      TestPromise.new(iface: self, wait_for: [promise]).to_execute {}
    end

    def assert(value, msg = nil)
      id = start_assertion("#{caller[0]}: #{msg || "Value should be true!"}")

      if value
        pass_assertion(id)
      else
        fail_assertion(id)
      end
    end

    def assert_equal(val1, val2, msg=nil)
      assert val1 == val2, (msg || "Expected #{val2.inspect} to equal #{val1.inspect}!")
    end

    # How do we signal an error?
    def with_js_value(js_code, wait_for: [], timeout: DEFAULT_ASSERTION_TIMEOUT, &block)
      unless block
        raise "Must give a block to with_js_value!"
      end
      js_promise = wrangler.eval_js_async(js_code, wait_for: wait_for, timeout: timeout)
      ruby_promise = TestPromise.new(iface: self, wait_for: [js_promise])
      ruby_promise.to_execute(&block)
      ruby_promise
    end

    def with_js_dom_html(wait_for: [], timeout: DEFAULT_ASSERTION_TIMEOUT, &block)
      with_js_value("document.getElementById('wrapper-wvroot').innerHTML", wait_for: wait_for, timeout: timeout, &block)
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

    def then_assert_js(js_code, wait_for: [], timeout: DEFAULT_ASSERTION_TIMEOUT)
      # These (wait_for + [self]) args are sometimes in the other order due to questions about
      # how they should handle passing returned_values from parents to blocks... That's gonna be difficult to get right :-/
      assert_js(js_code, wait_for: (wait_for + [self]), timeout: timeout)
    end

    def then_with_js_dom_html(wait_for: [], timeout: DEFAULT_ASSERTION_TIMEOUT, &block)
      @iface.with_js_dom_html(wait_for: (wait_for + [self]), timeout: timeout, &block)
    end

    # Evaluate the JS, then call a Ruby block with the result
    def then_ruby_with_js_value(js_code, wait_for: [], timeout: DEFAULT_ASSERTION_TIMEOUT, &block)
      js_promise = @iface.wrangler.eval_js_async(js_code, wait_for: [self], timeout: timeout)

      then_ruby(wait_for: [js_promise], &block)
    end

    def then_ruby(wait_for: [], &block)
      ruby_promise = TestPromise.new iface: @iface, wait_for: ([self] + wait_for)

      # Once the Ruby promise gets scheduled, we can just call the Ruby code to fulfill or reject it
      ruby_promise.to_execute(&block)
      ruby_promise.on_rejected do
        puts "Ruby promise got an error! #{ruby_promise.reason.full_message}!"
      end
    end

    # This method expects to wait for the parent TestPromise and then run a block of Ruby that returns
    # another promise. This is useful for wrapping Promises like those from replace() that don't have
    # the test DSL built in. The block will execute when this outer promise is scheduled -- so we don't do
    # a replace() too early, for instance. And then the outer promise will fulfill when the inner one does.
    def then_ruby_promise(wait_for: [], &block)
      ruby_wrapper_promise = TestPromise.new iface: @iface, wait_for: ([self] + wait_for)

      ruby_wrapper_promise.on_scheduled {
        inner_ruby_promise = block.call
        inner_ruby_promise.on_fulfilled { ruby_wrapper_promise.fulfilled!(inner_ruby_promise.returned_value) }
      }
    end

    # Gives back a no-op promise that depends on the DOM finishing a redraw, plus the parent promise
    def and_when_fully_updated(wait_for: [])
      dom_promise = @iface.wrangler.promise_dom_fully_updated
      p = TestPromise.new(iface: @iface, wait_for: ([self, dom_promise] + wait_for))
      p.to_execute {}
    end
  end
end
