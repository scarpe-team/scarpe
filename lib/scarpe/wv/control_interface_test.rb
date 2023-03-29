# frozen_string_literal: true

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

    # This does a final return of results. Don't call it yourself
    # unless you want any other results that would be returned
    # to be wiped out.
    def return_results(result_structs)
      if @results_returned
        raise "Returning more than one set of results! Bad!"
      end

      result_file = ENV["SCARPE_TEST_RESULTS"] || "./scarpe_results.txt"
      puts "Writing results file #{result_file.inspect} to disk!" if @debug
      File.write(result_file, JSON.pretty_generate(result_structs))

      @results_returned = true
    end

    # We want an assertions library, but one that runs inside the spawned
    # Webview sub-process.

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
  end
end
