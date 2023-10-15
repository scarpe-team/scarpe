# frozen_string_literal: true

require "minitest"
require "scarpe/cats_cradle" # Currently needed for CCHelpers

# Test framework code to allow Scarpe to execute Shoes-Spec test code.
# This will run inside the exe/scarpe child process, then send
# results back to the parent Minitest process.

module Scarpe::Test
  # Cut down from Rails camelize
  def self.camelize(string)
    string = string.sub(/^[a-z\d]*/) { |match| match.capitalize }
    string.gsub(/(?:_|(\/))([a-z\d]*)/) { "#{$1}#{$2.capitalize}" }
  end

  # Is it at all reasonable to define more than one test to run in the same Shoes run? Probably not.
  # They'll leave in-memory residue.
  def self.run_shoes_spec_test_code(code, class_name: "TestShoesSpecCode", test_name: "test_shoes_spec")
    if @shoes_spec_init
      raise MultipleShoesSpecRunsError, "Scarpe-Webview can only run a single Shoes spec per process!"
    end
    @shoes_spec_init = true

    require_relative "cats_cradle"

    # We want Minitest assertions available in the test code.
    # But this will normally run in a subprocess. So we need
    # to run Minitest tests and then export the results.

    test_obj = Object.new
    class << test_obj
      include Scarpe::Test::CatsCradle
    end
    test_obj.instance_eval do
      event_init

      on_heartbeat do
        Minitest.run ARGV

        test_finished_no_results
      end
    end

    test_class = Class.new(Scarpe::ShoesSpecTest)
    Object.const_set(camelize(class_name), test_class)
    test_name = "test_" + test_name unless test_name.start_with?("test_")
    test_class.define_method(test_name) do
      eval(code)
      #test_obj.instance_variable_get(:@cc_instance).instance_eval(code)
    end
  end
end

# When running ShoesSpec tests, we create a parent class for all of them
# with the appropriate convenience methods and accessors.
class Scarpe::ShoesSpecTest < Minitest::Test
  include Scarpe::Test::CCHelpers
end
