# frozen_string_literal: true

require "minitest"
require "json"
#require "json/add/exception"

module Scarpe; module Components; end; end

# A MinitestResult imports a JSON file from a minitest_export_reporter.
# But instead of creating a Minitest::Test to report the result, the
# MinitestResult is just a queryable Ruby object.
#
# MinitestResult assumes there will be only one class and one method
# in the JSON, which is true for Scarpe but not necessarily in general.
class Scarpe::Components::MinitestResult
  attr_reader :assertions
  attr_reader :method_name
  attr_reader :class_name

  def initialize(filename)
    data = JSON.parse File.read(filename)

    unless data.size == 1
      # We would want a different interface to support this in general. For now we don't
      # need it to work in general.
      raise "Scarpe::Components::MinitestResult only supports one class and method in results!"
    end

    item = data.first

    @assertions = item["assertions"]
    @method_name = item["name"]
    @class_name = item["klass"]
    @time = item["time"]
    @metadata = item.key?("metadata") ? item["metadata"]: {}

    @skip = false
    @exceptions = []
    @failures = []
    item["failures"].each do |f|
      # JSON.parse ignores json_class and won't create an arbitrary object. That's good
      # because Minitest::UnexpectedError seems to load in a bad way, so we don't want
      # it to auto-instantiate.
      d = JSON.parse f[1]
      msg = d["m"]
      case d["json_class"]
      when "Minitest::UnexpectedError"
        @exceptions << msg
      when "Minitest::Skip"
        @skip = msg
      when "Minitest::Assertion"
        @failures << msg
      else
        raise Scarpe::InternalError, "Didn't expect type #{t.inspect} as exception type when importing Minitest tests!"
      end
    end
  end

  def error?
    !@exceptions.empty?
  end

  def fail?
    !@failures.empty?
  end

  def skip?
    @skip ? true : false
  end

  def passed?
    @exceptions.empty? && @failures.empty? && !@skip
  end

  def error_message
    @exceptions[0]
  end

  def fail_message
    @failures[0]
  end

  def skip_message
    @skip
  end
end
