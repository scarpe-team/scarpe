# frozen_string_literal: true

require_relative "helper"

class DisplacementTest < Minitest::Test
  include NativeTestHelpers

  def test_displacement_updates_visual_rects_without_changing_logical_positions
    skip_without_real_binary
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app(width: 300, height: 200) do
        @pane = stack(left: 10, top: 20, width: 100, height: 80) do
          @moving = button "Move", left: 4, top: 6, width: 60, height: 30
        end
      end
    APP
      window = Shoes.APPS.first
      pane = window.instance_variable_get(:@pane)
      moving = window.instance_variable_get(:@moving)
      logical = [moving.left, moving.top]
      cache = Shoes::DisplayService.layout_cache
      visual = cache.fetch(moving.linkable_id).dup
      pane.displace(80, 40)
      wait_frames
      assert_equal logical, [moving.left, moving.top]
      assert_equal [visual[0] + 80, visual[1] + 40], cache.fetch(moving.linkable_id).first(2)
      pane.style(displace_left: nil, displace_top: nil)
      wait_frames
      assert_equal logical, [moving.left, moving.top]
      assert_equal visual, cache.fetch(moving.linkable_id)
    TEST
    assert_spec_passed(run)
  end
end
