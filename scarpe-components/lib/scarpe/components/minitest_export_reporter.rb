# frozen_string_literal: true

# Have to require this to get DefaultReporter and the Minitest::Reporters namespace.
ENV["MINITEST_REPORTER"] = "ShoesExportReporter"
require "minitest/reporters"
require "json"
require "json/add/exception"

module Minitest
  module Reporters
    # To use this Scarpe component, you'll need minitest-reporters in your Gemfile,
    # probably in the "test" group. You'll need to require and activate ShoesExportReporter
    # to register it as Minitest's reporter:
    #
    #     require "scarpe/components/minitest_export_reporter"
    #     Minitest::Reporters::ShoesExportReporter.activate!
    #
    # Select a destination to export JSON test results to:
    #
    #     export SHOES_MINITEST_EXPORT_FILE=/tmp/shoes_test_export.json
    #
    # This class overrides the MINITEST_REPORTER environment variable when you call activate.
    # If MINITEST_REPORTER isn't set then when you run via Vim, TextMate, RubyMine, etc,
    # the reporter will be automatically overridden and print to console instead.
    #
    # Based on https://gist.github.com/davidwessman/09a13840a8a80080e3842ac3051714c7
    class ShoesExportReporter < DefaultReporter
      def self.activate!
        unless ENV["SHOES_MINITEST_EXPORT_FILE"]
          raise "ShoesExportReporter is available, but no export file was specified! Set SHOES_MINITEST_EXPORT_FILE!"
        end

        Minitest::Reporters.use!
      end

      def serialize_failures(failures)
        failures.map do |fail|
          case fail
          when Minitest::UnexpectedError
            ["unexpected", fail.to_json, fail.error.to_json]
          when Exception
            ["exception", fail.to_json]
          else
            raise "Not sure how to serialize failure object! #{fail.inspect}"
          end
        end
      end

      def report
        super

        results = tests.map do |result|
          failures = serialize_failures result.failures
          {
            name: result.name,
            klass: test_class(result),
            assertions: result.assertions,
            failures: failures,
            time: result.time,
            metadata: result.respond_to?(:metadata) ? result.metadata : {},
            source_location: begin
              result.source_location
            rescue
              ["unknown", -1]
            end,
          }
        end

        out_file = File.expand_path ENV["SHOES_MINITEST_EXPORT_FILE"]
        puts "Writing Minitest results to #{out_file.inspect}."
        File.write(out_file, JSON.dump(results))
      end
    end
  end
end
