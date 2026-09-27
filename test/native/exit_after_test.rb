# frozen_string_literal: true

require_relative "helper"

# `--exit-after SECS` ends a run the way a person closing the window would, headless too: Rust
# reports every app closed and Ruby quits them. Headless Rust used to exit mid-run, which the
# shim rightly reported as a crash.
class ExitAfterTest < Minitest::Test
  include NativeTestHelpers

  def setup
    skip_without_real_binary
  end

  def test_headless_exit_after_quits_cleanly
    run = run_real(<<~APP, env: { "SCARPE_NATIVE_ARGS" => "--fonts bundled --exit-after 0.5" })
      Shoes.app { para "Hello" }
    APP
    assert_clean_exit(run)
    refute_match(/ChildDied/, run.stderr, "the shim saw a clean close, not a crash")
  end
end
