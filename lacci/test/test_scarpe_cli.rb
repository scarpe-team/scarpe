# frozen_string_literal: true

require_relative "test_helper"
require "lacci/scarpe_cli"

class TestScarpeCli < Minitest::Test
  def test_usage_names_the_native_display_and_peek
    usage = Scarpe::CLI::DEFAULT_USAGE

    assert_match(/^\s+--native\s+\S/, usage, "--native is an option")
    assert_match(/^\s*scarpe peek APP\.rb/, usage, "peek is a command")
  end
end
