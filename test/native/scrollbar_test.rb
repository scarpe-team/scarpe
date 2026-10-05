# frozen_string_literal: true

require_relative "helper"

class NativeScrollbarTest < Minitest::Test
  include NativeTestHelpers

  def setup
    skip_without_real_binary
  end

  def test_drag_and_track_clicks_update_ruby_scroll_top_and_preserve_focus
    run = run_real(<<~APP, test_code: <<~TEST)
      $events = []
      Shoes.app(width: 400, height: 260) do
        @list = stack(left: 20, top: 20, width: 100, height: 100, scroll: true) do
          @content = stack(height: 500) do
            button("Under thumb", width: 100, height: 28) { $events << :button }
          end
          click { $events << :list_click }
          release { $events << :list_release }
        end
        @query = edit_line(left: 150, top: 20, width: 180)
        click { $events << :app_click }
        release { $events << :app_release }
      end
    APP
      click_at(180, 30)
      $events.clear
      drag([114, 30], [114, 66])
      assert_equal 200, stack("@list").scroll_top
      assert_equal(-180, layout_of(stack("@content")).y)
      hover_at(114, 100)
      assert_equal 200, stack("@list").scroll_top, "release ends the drag"

      click_at(114, 105)
      assert_equal 290, stack("@list").scroll_top, "track click pages by 90% of the viewport"
      click_at(114, 25)
      assert_equal 200, stack("@list").scroll_top, "click above the thumb pages up"
      type_text("still focused")
      assert_equal "still focused", edit_line("@query").text
      assert_empty $events, "scrollbar input never activates the controls or slots beneath it"

      stack("@list").scroll_top = 0
      wait_frames(1)
      click_at(50, 30)
      assert_equal [:button], $events, "ordinary clicks still reach the control"
    TEST
    assert_spec_passed(run)
  end

  def test_hiding_a_scroller_cancels_its_drag_without_delivering_release_to_the_app
    run = run_real(<<~APP, test_code: <<~TEST)
      $releases = 0
      Shoes.app(width: 400, height: 260) do
        @list = stack(left: 20, top: 20, width: 100, height: 100, scroll: true) do
          stack(height: 500)
        end
        release { $releases += 1 }
      end
    APP
      automation.mouse(:down, 114, 30)
      stack("@list").hide
      wait_frames(1)
      stack("@list").show
      wait_frames(1)
      automation.mouse(:move, 114, 66)
      automation.mouse(:up, 114, 66)
      assert_equal 0, stack("@list").scroll_top
      assert_equal 0, $releases

      drag([114, 30], [114, 66])
      assert_equal 200, stack("@list").scroll_top, "a fresh press starts a new drag"
    TEST
    assert_spec_passed(run)
  end
end
