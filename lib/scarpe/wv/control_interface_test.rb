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
  end
end
