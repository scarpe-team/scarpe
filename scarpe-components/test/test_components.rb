# frozen_string_literal: true

require_relative "test_helper"

class TestScarpeComponents < Minitest::Test
  # Top-level tests go here?
end

require "scarpe/components/process_helpers"
class TestComponentHelpers < Minitest::Test
  include Scarpe::Components::ProcessHelpers

  def test_process_runner_stdout
    out, err, success = run_out_err_result("echo ok")
    assert success, "Echoing okay should succeed!"
    assert_equal "", err
    assert_includes out, "ok"
  end

  def test_process_runner_stderr
    out, err, success = run_out_err_result("echo ok 1>&2")
    assert success, "Echoing okay to stderr should succeed!"
    assert_equal "", out
    assert_includes err, "ok"
  end

  def test_process_runner_fail
    out, err, success = run_out_err_result("ls no_such_file_exists")
    assert !success, "ls on nonexistent file should return failure!"
    assert_equal "", out
    assert err != "", "ls on nonexistent file should give non-empty error output"
  end

  def test_process_runner_command_array
    out, err, success = run_out_err_result(["echo", "ok"])
    assert success, "Echoing okay via command array should succeed!"
  end
end
