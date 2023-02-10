# frozen_string_literal: true

require "test_helper"

class TestScarpe < Minitest::Test
  def test_examples
    examples_to_test = Dir["examples/**/*.rb"]
      .reject { _1.include?("/not_checked/") }
      .reject { _1.include?("/skip_ci/") if ENV["CI_RUN"] }

    puts "Testing #{examples_to_test.count} examples"

    examples_to_test.each do |example|
      test_scarpe_app(example, exit_immediately: true)
    end
  end
end
