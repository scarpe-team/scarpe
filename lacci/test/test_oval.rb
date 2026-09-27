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
end
