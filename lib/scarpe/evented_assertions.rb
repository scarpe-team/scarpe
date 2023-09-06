# frozen_string_literal: true

require "tempfile"
require "json"
require "fileutils"

module Scarpe::Test; end

# We need a separate assertion system for the kind of Scarpe
# testing where we start a subprocess, perform the assertion
# logic in the subprocess, and then run Minitest in the parent.
# It's an unusual setup.
module Scarpe::Test::EventedAssertions
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
  # @see Scarpe::Components::HTML.render
  #
  # @param actual_html [String] the html to compare to
  # @param expected_tag [String,Symbol] the HTML tag, used to send a method call
  # @param opts keyword options passed to the tag method call
  # @yield block passed to the tag method call.
  # @return [void]
  def assert_html(actual_html, expected_tag, **opts, &block)
    expected_html = Scarpe::Components::HTML.render do |h|
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
