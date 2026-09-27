# frozen_string_literal: true

require_relative "helper"

class ExampleRunTest < Minitest::Test
  def test_steps_become_peek_arguments_in_order
    example = SpecSuite::ExampleList::Example.new(path: "examples/demo.rb", steps: [{ "click_at" => [200, 200] }, { "wait" => 0.5 }, { "key" => "tab" }])
    run = SpecSuite::ExampleRun.new(example, display: "native", tree: nil, sandboxes: nil)

    assert_equal ["--click-at", "200,200", "--wait", "0.5", "--key", "tab"], run.send(:step_args)
  end

  def test_an_unknown_step_names_the_example
    example = SpecSuite::ExampleList::Example.new(path: "examples/demo.rb", steps: [{ "hover" => [1, 2] }])
    run = SpecSuite::ExampleRun.new(example, display: "native", tree: nil, sandboxes: nil)

    error = assert_raises(ArgumentError) { run.send(:step_args) }
    assert_match(/examples\/demo\.rb: unknown peek step "hover"/, error.message)
  end
end
