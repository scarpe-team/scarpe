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

      assert_equal 30, para("@words").height, "14.4 px of text plus its 4 px margin above and 12 below"
      assert_equal [70, 0, 40, 24], [button("@go").left, button("@go").top, button("@go").width, button("@go").height]
    SHOES_SPEC
  end

  # Shoes 3 reports an element's place, margins included (s3_ruby.h:376-413 read
  # place.x, place.y, place.w and place.h), and text blocks carry 4 px margins with
  # 12 below (ledger C9). The display pushes the box inside the margins.
  def test_getters_report_the_box_with_its_margins
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @plain = para "plain"
        @spaced = para "spaced", margin: 10
        @tall = para "tall", margin_left: 2
        @sized = para "sized", width: 200
        @go = button "Go", margin: [5, 6, 7, 8]
        @styled = stack
        @styled.style(margin: 3)
      end
    SHOES_APP
      cache = Shoes::DisplayService.layout_cache
      box = ->(name) { d = drawable(name); [d.left, d.top, d.width, d.height] }
      cache[para("@plain").linkable_id] = [4.0, 4.0, 64.0, 14.4, 14.4]
      cache[para("@spaced").linkable_id] = [10.0, 40.0, 64.0, 14.4, 14.4]
      cache[para("@tall").linkable_id] = [2.0, 80.0, 64.0, 14.4, 14.4]
      cache[para("@sized").linkable_id] = [4.0, 120.0, 200.0, 14.4, 14.4]
      cache[button("@go").linkable_id] = [105.0, 206.0, 40.0, 24.0, 24.0]
      cache[stack("@styled").linkable_id] = [3.0, 303.0, 594.0, 0.0, 0.0]

      assert_equal [0, 0, 72, 30], box.("@plain"), "4 px round the text and 12 below"
      assert_equal [0, 30, 84, 34], box.("@spaced"), "margin: 10 on every side, the 12 below included"
      assert_equal [0, 76, 70, 30], box.("@tall"), "one side given, the others keep the text defaults"
      assert_equal 200, para("@sized").width, "a pixel width the app gave is still the answer"
      assert_equal [100, 200, 52, 38], box.("@go"), "a control has no margin unless given one"
      assert_equal [0, 300, 600, 6], box.("@styled"), "a margin set later through style counts too"
    SHOES_SPEC
  end

  # Manual 2623-2626: left and top of a displaced element read "as if there was no
  # displacement". The display pushes where it painted, so the displacement comes off,
  # a displaced slot's included.
  def test_left_and_top_ignore_displacement
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @box = stack(margin: 0) { @go = button "Go" }
      end
    SHOES_APP
      cache = Shoes::DisplayService.layout_cache
      stack("@box").displace(10, 20)
      button("@go").displace(2, 6)
      cache[stack("@box").linkable_id] = [10.0, 20.0, 600.0, 24.0, 24.0]
      cache[button("@go").linkable_id] = [12.0, 26.0, 40.0, 24.0, 24.0]

      assert_equal [0, 0], [stack("@box").left, stack("@box").top]
      assert_equal [0, 0], [button("@go").left, button("@go").top]
    SHOES_SPEC
  end

  def test_scroll_height_and_scroll_max_come_from_the_content_height
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @list = stack width: 200, height: 100, scroll: true, margin: 10 do
          5.times { stack height: 40 }
        end
        @short = stack width: 200, height: 100
      end
    SHOES_APP
      Shoes::DisplayService.layout_cache[stack("@list").linkable_id] = [0.0, 0.0, 200.0, 100.0, 200.0]
      Shoes::DisplayService.layout_cache[stack("@short").linkable_id] = [0.0, 100.0, 200.0, 100.0, 100.0]

      assert_equal 200, stack("@list").scroll_height
      assert_equal 100, stack("@list").scroll_max, "scrolling is measured in the viewport, inside the margins"
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
