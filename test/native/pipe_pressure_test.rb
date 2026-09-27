# frozen_string_literal: true

require_relative "helper"

# The real Rust child under the pipe pressure Shoes-Spec's `advance` puts on it: thousands of
# animation ticks, each one flushed, and nothing read back until the next request. Headless Rust
# used to read stdin on the thread that writes stdout, so after a pipe's worth of layout lines
# both processes blocked writing to each other for good.
class PipePressureTest < Minitest::Test
  include NativeTestHelpers

  def setup
    skip_without_real_binary
  end

  def test_advance_through_a_minute_of_moving_art
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        $frames = 0
        @dot = oval 0, 0, 10
        animate(60) do |frame|
          $frames += 1
          @dot.move(frame % 300, frame % 200)
        end
      end
    APP
      advance 60
      assert_equal 3600, $frames, "every frame of the minute ran"
      dot = layout_of(oval("@dot"))
      assert_equal [3599 % 300, 3599 % 200], [dot.x, dot.y], "and Rust drew the dot where the last one put it"
    TEST
    assert_spec_passed(run)
  end
end
