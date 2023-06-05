# frozen_string_literal: true

require "test_helper"

class TestExamplesWithWebview < Minitest::Test
  match_str = ENV["EXAMPLES_MATCHING"] || ""

  examples_to_test = Dir["examples/**/*.rb"]
    .reject { !_1.include?(match_str) }
    .reject { _1.include?("/not_checked/") }
    .reject { _1.include?("/skip_ci/") if ENV["CI_RUN"] }

  examples_to_test.each do |example_filename|
    example = example_filename.gsub("/", "_").gsub("-", "_").gsub(/.rb\Z/, "")
    define_method("test_webview_#{example}") do
      test_scarpe_app(example_filename, exit_immediately: true)
    end
  end
end
