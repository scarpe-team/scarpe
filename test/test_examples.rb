# frozen_string_literal: true

require "test_helper"

class TestScarpe < Minitest::Test
  def test_examples
    examples_to_test = Dir["examples/**/*.rb"].reject { _1.include?("/not_checked/") }

    puts "Testing #{examples_to_test.count} examples"

    examples_to_test.each do |example|
      puts "Testing #{example}"
      test_scarpe_app(example, exit_immediately: true)
    end
  end
end
