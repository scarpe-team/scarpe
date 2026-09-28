# frozen_string_literal: true

require_relative "helper"

class ExampleRunTest < Minitest::Test
  def test_steps_become_peek_arguments_in_order
    example = SpecSuite::ExampleList::Example.new(path: "examples/demo.rb", steps: [{ "click_at" => [200, 200] }, { "wait" => 0.5 }, { "key" => "tab" }])
    run = SpecSuite::ExampleRun.new(example, display: "native", tree: nil, sandboxes: nil)

    assert_equal ["--click-at", "200,200", "--wait", "0.5", "--key", "tab"], run.send(:step_args)
  end

  def test_a_drag_step_passes_its_points_flat
    example = SpecSuite::ExampleList::Example.new(path: "examples/demo.rb", steps: [{ "drag" => [[100, 100], [150, 120], [200, 90]] }])
    run = SpecSuite::ExampleRun.new(example, display: "native", tree: nil, sandboxes: nil)

    assert_equal ["--drag", "100,100,150,120,200,90"], run.send(:step_args)
  end

  def test_dialogs_become_the_stubbed_answers
    example = SpecSuite::ExampleList::Example.new(path: "examples/demo.rb", dialogs: { "confirm" => true, "ask_color" => "#f80" })
    run = SpecSuite::ExampleRun.new(example, display: "niente", tree: nil, sandboxes: nil)

    assert_equal({ "SPEC_DIALOG_STUBS" => '{"confirm":true,"ask_color":"#f80"}' }, run.send(:dialog_stubs))
    assert_empty SpecSuite::ExampleRun.new(SpecSuite::ExampleList::Example.new(path: "x.rb"), display: "native", tree: nil, sandboxes: nil).send(:dialog_stubs)
  end

  def test_a_warning_that_names_an_exception_is_not_an_error
    run = SpecSuite::ExampleRun.new(SpecSuite::ExampleList::Example.new(path: "x.rb"), display: "native", tree: nil, sandboxes: nil)
    warned = "[scarpe-native] Scarpe::Native::Normalize warn: Could not download https://x/y.png: OpenSSL::SSL::SSLError: eof\n"
    run.instance_variable_set(:@tree, Struct.new(:root).new("/nowhere"))

    assert_nil run.send(:first_error, warned)
    assert_match(/NoMethodError/, run.send(:first_error, "app.rb:3:in 'block': undefined method 'x' for nil (NoMethodError)\n"))
  end

  # colours.rb paints every square black but not one flat colour; pixels: is how its row can say so.
  def test_pixels_the_snapshot_must_show
    checker = File.join(SpecSuite::REPO, "spec", "support", "assets", "checker-20x20.png")
    finished = Struct.new(:output, :timed_out, :exitstatus).new("", false, 0)
    judge = ->(pixels) do
      example = SpecSuite::ExampleList::Example.new(path: "examples/demo.rb", pixels:)
      SpecSuite::ExampleRun.new(example, display: "native", tree: nil, sandboxes: nil).send(:judge_peek, finished, checker)
    end

    assert_equal "pass", judge.([[2, 2, "#000000"], [15, 5, "#FFFFFF"]]).first
    assert_equal ["fail", "pixel 15,5 is #ffffff, not #000000"], judge.([[2, 2, "#000000"], [15, 5, "#000000"]])
  end

  # ruby_racer.rb stops on `require "benchmark"` only where Ruby 4.0 made benchmark a bundled gem;
  # on 3.2 it loads, and CI runs both.
  def test_a_status_can_hold_on_some_rubies_only
    example = SpecSuite::ExampleList::Example.new(path: "examples/demo.rb", status: "fails", ruby: ">= 4.0")

    assert_equal "fails", example.status_on("native", ruby_version: "4.0.1")
    assert_equal "loads", example.status_on("native", ruby_version: "3.2.11")
    assert_equal "fails", SpecSuite::ExampleList::Example.new(path: "x.rb", status: "fails").status_on("native", ruby_version: "3.2.0")
  end

  def test_a_ruby_that_is_not_a_requirement_is_a_problem
    list = SpecSuite::ExampleList.new("examples/demo.rb" => { "status" => "fails", "ruby" => "four or newer" },
      "examples/fine.rb" => { "status" => "fails", "ruby" => ">= 4.0" })

    assert_equal ["examples/demo.rb: ruby \"four or newer\" is not a version requirement like \">= 4.0\""], list.problems
  end

  def test_an_unknown_step_names_the_example
    example = SpecSuite::ExampleList::Example.new(path: "examples/demo.rb", steps: [{ "hover" => [1, 2] }])
    run = SpecSuite::ExampleRun.new(example, display: "native", tree: nil, sandboxes: nil)

    error = assert_raises(ArgumentError) { run.send(:step_args) }
    assert_match(/examples\/demo\.rb: unknown peek step "hover"/, error.message)
  end
end
