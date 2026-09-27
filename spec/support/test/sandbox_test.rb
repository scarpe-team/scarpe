# frozen_string_literal: true

require_relative "helper"

class SandboxTest < Minitest::Test
  def test_case_names_differing_only_in_punctuation_get_separate_sandboxes
    names = %w[manual/widgets-text/check.checked?.sspec manual/widgets-text/check.checked=.sspec]
      .map { |path| SpecSuite::Sandbox.dir_name(path) }

    assert_equal 2, names.uniq.size, "check.checked? and check.checked= must not share a directory: #{names.inspect}"
  end

  def test_sandbox_names_stay_readable_and_stable
    name = SpecSuite::Sandbox.dir_name("manual/styles/styles.width.sspec")

    assert name.start_with?("manual_styles_styles.width.sspec-"), "the case path still leads the name: #{name}"
    assert_equal name, SpecSuite::Sandbox.dir_name("manual/styles/styles.width.sspec"), "the same case gets the same name"
    assert_match(/\A[\w.-]+\z/, name, "and the name is safe as one path component")
  end
end
