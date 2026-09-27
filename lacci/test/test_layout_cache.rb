# frozen_string_literal: true

require_relative "test_helper"

# A display that lays drawables out pushes their rects back into
# Shoes::DisplayService.layout_cache[id] = [x, y, w, h, scroll_h] (window pixels).
# Getters read it, so width, height, left, top, scroll_height and scroll_max report
# what is on screen (ledger A4, C5). Niente pushes nothing, so they fall back.
class TestLayoutCache < NienteTest
  def test_an_unsized_slot_reports_where_the_display_put_it
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @box = stack { para "hi" }
      end
    SHOES_APP
      box = stack("@box")
      Shoes::DisplayService.layout_cache[box.linkable_id] = [120.0, 30.4, 199.6, 69.5, 69.5]

      assert_equal [120, 30, 200, 70], [box.left, box.top, box.width, box.height]
    SHOES_SPEC
  end

  def test_a_number_the_app_gave_wins_over_the_layout
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @box = stack left: 10, top: 20, width: 200, height: 50
      end
    SHOES_APP
      box = stack("@box")
      Shoes::DisplayService.layout_cache[box.linkable_id] = [110.0, 120.0, 180.0, 40.0, 40.0]

      assert_equal [10, 20, 200, 50], [box.left, box.top, box.width, box.height]
    SHOES_SPEC
  end

  def test_relative_sizes_read_the_layout
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @half = stack width: 0.5
        @pct = stack width: "25%"
        @less = stack width: -100
      end
    SHOES_APP
      %w[@half @pct @less].each_with_index do |name, i|
        Shoes::DisplayService.layout_cache[stack(name).linkable_id] = [0.0, 0.0, 111.0 + i, 5.0, 5.0]
      end

      assert_equal [111, 112, 113], %w[@half @pct @less].map { |name| stack(name).width }
    SHOES_SPEC
  end

  def test_text_and_controls_get_their_shown_size
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @words = para "some words"
        @go = button "Go"
      end
    SHOES_APP
      assert_nil para("@words").height, "nothing laid out yet"

      Shoes::DisplayService.layout_cache[para("@words").linkable_id] = [0.0, 0.0, 64.0, 14.4, 14.4]
      Shoes::DisplayService.layout_cache[button("@go").linkable_id] = [70.0, 0.0, 40.0, 24.0, 24.0]

      assert_equal 14, para("@words").height
      assert_equal [70, 0, 40, 24], [button("@go").left, button("@go").top, button("@go").width, button("@go").height]
    SHOES_SPEC
  end

  def test_scroll_height_and_scroll_max_come_from_the_content_height
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @list = stack width: 200, height: 100, scroll: true do
          5.times { stack height: 40 }
        end
        @short = stack width: 200, height: 100
      end
    SHOES_APP
      Shoes::DisplayService.layout_cache[stack("@list").linkable_id] = [0.0, 0.0, 200.0, 100.0, 200.0]
      Shoes::DisplayService.layout_cache[stack("@short").linkable_id] = [0.0, 100.0, 200.0, 100.0, 100.0]

      assert_equal 200, stack("@list").scroll_height
      assert_equal 100, stack("@list").scroll_max
      assert_equal 0, stack("@short").scroll_max
    SHOES_SPEC
  end

  def test_with_no_layout_a_slot_scrolls_nowhere
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @box = stack height: 80
      end
    SHOES_APP
      assert_equal 80, stack("@box").scroll_height
      assert_equal 0, stack("@box").scroll_max
    SHOES_SPEC
  end

  # Manual 1239-1245: a decimal is a fraction of the parent. Floats above 1 are pixels,
  # as the native display reads them (native/src/style/dim.rs).
  def test_without_a_layout_sizes_resolve_like_the_display_does
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app width: 400, height: 400 do
        @outer = stack width: 300, height: 200 do
          @half = stack width: 0.5, height: 0.5
          @all = stack width: 1.0
          @px = stack width: "120px"
          @wide = stack width: 150.5
        end
      end
    SHOES_APP
      assert_equal [150, 100], [stack("@half").width, stack("@half").height]
      assert_equal 300, stack("@all").width
      assert_equal 120, stack("@px").width
      assert_equal 150.5, stack("@wide").width
      assert_equal 0.5, stack("@half").style[:width], "the style keeps what was asked for"
    SHOES_SPEC
  end

  def test_destroying_a_drawable_forgets_its_rect
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @box = stack { para "bye" }
      end
    SHOES_APP
      id = stack("@box").linkable_id
      Shoes::DisplayService.layout_cache[id] = [0.0, 0.0, 10.0, 10.0, 10.0]
      stack("@box").remove

      refute Shoes::DisplayService.layout_cache.key?(id)
    SHOES_SPEC
  end

  def test_a_slot_knows_the_gutter
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @box = stack { para "inside" }
      end
    SHOES_APP
      assert_equal Shoes.APPS.first.gutter, stack("@box").gutter
    SHOES_SPEC
  end
end
