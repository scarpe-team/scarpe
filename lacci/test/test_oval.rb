# frozen_string_literal: true

require_relative "test_helper"

class TestLacciOval < NienteTest
  # For an oval, the positional args go left, top, width, height. The third
  # argument is the diameter: the manual (manual.md:1716-1722, "a width and
  # height of `radius` pixels"), Shoes 3 and Shoes 4 agree (research 06, E1).
  def test_simple_oval_values
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        oval 5, 10, 50 # circle 50 across with its upper-left point at 5, 10
      end
    SHOES_APP
      ov = oval()
      assert_equal 5, ov.left
      assert_equal 10, ov.top
      assert_equal 25, ov.radius
      assert_equal 50, ov.width
      assert_equal 50, ov.height
    SHOES_SPEC
  end

  def test_oval_with_height
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        oval 5, 10, 50, 35 # oval 50 wide, 35 tall
      end
    SHOES_APP
      ov = oval()
      assert_equal 5, ov.left
      assert_equal 10, ov.top
      assert_equal 25, ov.radius
      assert_equal 50, ov.width
      assert_equal 35, ov.height
    SHOES_SPEC
  end

  # The radius: style stays a true radius (manual.md:1348-1354).
  def test_simple_oval_keyword_values
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        oval left: 5, top: 10, radius: 25
      end
    SHOES_APP
      ov = oval()
      assert_equal 5, ov.left
      assert_equal 10, ov.top
      assert_equal 25, ov.radius
      assert_equal 50, ov.height
      assert_equal 50, ov.width
    SHOES_SPEC
  end

  def test_oval_keywords_with_height_but_no_radius
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        oval left: 5, top: 10, height: 25
      end
    SHOES_APP
      ov = oval()
      assert_equal 5, ov.left
      assert_equal 10, ov.top
      assert_equal 12, ov.radius
      assert_equal 25, ov.height
      assert_equal 25, ov.width
    SHOES_SPEC
  end

  def test_oval_strokewidth
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        strokewidth 3
        oval 5, 10, 50
      end
    SHOES_APP
      ov = oval()
      assert_equal 5, ov.left
      assert_equal 10, ov.top
      assert_equal 25, ov.radius
      assert_equal 3, ov.draw_context["strokewidth"]
      # assert_equal 3, ov.strokewidth # This should work but doesn't yet, see issue #476
    SHOES_SPEC
  end

  # Ledger C10: art may be placed by its far edges, and sized by both edges of an axis.
  def test_art_placed_by_its_far_edges
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $corner = rect right: 10, bottom: 10, width: 40, height: 20
        $band = rect left: 20, top: 30, right: 20, bottom: 50
        $dot = oval right: 0, top: 150, width: 30
        $stretched = oval left: 100, right: 100, top: 160, height: 30
        $spark = star right: 0, top: 40
        $sweep = arc right: 0, bottom: 0, width: 50, height: 50, angle1: 0, angle2: 3
        $pointer = arrow right: 0, top: 50, width: 30
      end
    SHOES_APP
      styles = ->(shape, *names) { names.map { |name| shape.style[name] } }
      assert_equal [nil, nil, 10, 10], styles.($corner, :left, :top, :right, :bottom), "no near edge is made up"
      assert_equal [nil, nil], styles.($band, :width, :height), "a rect between both edges takes no size"
      assert_equal [nil, 0, 30, 30], styles.($dot, :left, :right, :width, :height), "an oval still defaults to a circle"
      assert_equal [nil, 30], styles.($stretched, :width, :height), "but one between both edges keeps its span"
      assert_equal [0, 0, 0], [$spark, $sweep, $pointer].map { |shape| shape.style[:right] }
    SHOES_SPEC
  end
end
