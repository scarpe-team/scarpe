# frozen_string_literal: true

require "minitest"
require "json"
require "json/add/exception"

module Scarpe; module Components; end; end
module Scarpe::Components::ImportRunnables
  # Minitest Runnables are unusual - we expect to declare a class (like a Test) with
  # a lot of methods to run. The ImportRunnable is a single Runnable. But whenever
  # you tell it to import a JSON file, it will add all of the described tests to
  # its runnable methods.
  #
  # Normally that means that your subclass tests will run up front and produce
  # JSON files, then Minitest will autorun at the end and report all their
  # results.
  #
  # It wouldn't really make sense to create these runnables during the testing
  # phase, because Minitest has already decided what to run at that point.
  class ImportRunnable #< Minitest::Runnable
    # Import JSON from an exported Minitest run. Note that running this multiple
    # times with overlapping class names may be really bad.
    def self.import_json_data(data)
      @imported_classes ||= {}
      @imported_tests ||= {}

      JSON.parse(data).each do |item|
        klass = item["klass"]
        meth = item["name"]
        @imported_tests[klass] ||= {}
        @imported_tests[klass][meth] = item
      end

      @imported_tests.each do |klass_name, test_method_hash|
        klass = @imported_classes[klass_name]
        unless klass
          new_klass = Class.new(Minitest::Runnable)
          @imported_classes[klass_name] = new_klass
          ImportRunnable.const_set(klass_name, new_klass)
          klass = new_klass

          klass.define_singleton_method(:run_one_method) do |klass, method_name, reporter|
            reporter.prerecord klass, method_name
            imp = test_method_hash[method_name]

            res = Minitest::Result.new imp["name"]
            res.klass = imp["klass"]
            res.assertions = imp["assertions"]
            res.time = imp["time"]
            res.failures = ImportRunnable.deserialize_failures imp["failures"]
            res.metadata = imp["metadata"] if imp["metadata"]

            # Record the synthetic result built from imported data
            reporter.record res
          end
        end

        # Update "runnables" method to reflect all current known runnable tests
        klass_methods = test_method_hash.keys
        klass.define_singleton_method(:runnable_methods) do
          klass_methods
        end
      end
    end

    def self.json_to_err(err_json)
      klass = begin
        Object.const_get(err_json["json_class"])
      rescue
        nil
      end
      if klass && klass <= Minitest::Assertion
        klass.json_create(err_json)
      else
        err = Exception.json_create(err_json)
        Minitest::UnexpectedError.new(err)
      end
    end

    def self.deserialize_failures(failures)
      failures.map do |fail|
        # Instantiate the Minitest::Assertion or Minitest::UnexpectedError
        if fail[0] == "exception"
          exc_json = JSON.parse(fail[1])
          json_to_err exc_json
        elsif fail[0] == "unexpected"
          unexpected_json = JSON.parse(fail[1])
          inner_json = JSON.parse(fail[2])
          outer_err = json_to_err unexpected_json
          inner_err = json_to_err inner_json
          outer_err.error = inner_err
        else
          raise "Unknown exception data when trying to deserialize! #{fail.inspect}"
        end
      end
    end
  end
end
