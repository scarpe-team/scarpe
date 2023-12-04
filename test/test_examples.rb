# frozen_string_literal: true

require "test_helper"

class TestExamplesWithWebview < ShoesSpecLoggedTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

  match_str = ENV["EXAMPLES_MATCHING"] || ""

  examples_to_test = Dir["examples/**/*.rb"]
    .reject { !_1.include?(match_str) }
    .reject { _1.include?("/not_checked/") }
    .reject { _1.include?("/bloopsaphone/") } # How do we want to CI-check these?
    .reject { _1.include?("/skip_ci/") if ENV["CI_RUN"] }

  examples_to_test.each do |example_filename|
    example = example_filename.gsub("/", "_").gsub("-", "_").gsub(/.rb\Z/, "")
    define_method("test_webview_calzini_#{example}") do
      ENV["SCARPE_HTML_RENDERER"] = "calzini"
      run_test_scarpe_app(example_filename, exit_immediately: true)
    end
    define_method("test_webview_tiranti_#{example}") do
      ENV["SCARPE_HTML_RENDERER"] = "tiranti"
      run_test_scarpe_app(example_filename, exit_immediately: true)
    end
  end
end
