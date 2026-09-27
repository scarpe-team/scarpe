# frozen_string_literal: true

module SpecSuite
  # Reads the JSON that Lacci's ShoesExportReporter writes in the child
  # (scarpe-components/lib/scarpe/components/minitest_export_reporter.rb).
  # Classification follows scarpe-components' MinitestResult: UnexpectedError is an error,
  # Assertion a failure, Skip a skip.
  class MinitestOutcome
    attr_reader :status, :message, :assertions, :backtrace

    def self.read(path)
      return nil unless File.size?(path)

      tests = JSON.parse(File.read(path))
      tests.is_a?(Array) && tests.size == 1 ? new(tests.first) : nil
    rescue JSON::ParserError
      nil
    end

    def initialize(test)
      @assertions = test["assertions"]
      failures = test["failures"].map { |kind, failure, inner| Failure.new(kind, failure, inner) }
      worst = failures.min_by(&:rank)
      @status = worst ? worst.status : "pass"
      @message = worst&.message
      @backtrace = worst ? worst.backtrace : []
    end

    class Failure
      RANKS = { "error" => 0, "fail" => 1, "skip" => 2 }.freeze

      def initialize(kind, failure, inner)
        @outer = parse(failure)
        @inner = parse(inner) if kind == "unexpected"
      end

      def status
        case @outer["json_class"]
        when "Minitest::UnexpectedError" then "error"
        when "Minitest::Skip" then "skip"
        else "fail"
        end
      end

      def rank = RANKS.fetch(status)

      def message
        text = (@inner || @outer)["m"].to_s
        text = "#{@inner["json_class"]}: #{text}" if @inner && !text.start_with?(@inner["json_class"].to_s)
        text.lines.first(4).join.strip[0, 400]
      end

      def backtrace
        (@inner || @outer)["b"] || []
      end

      private

      def parse(json)
        json ? JSON.parse(json) : {}
      rescue JSON::ParserError
        { "m" => json.to_s }
      end
    end
  end
end
