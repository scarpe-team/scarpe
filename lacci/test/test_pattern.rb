# frozen_string_literal: true

require_relative "test_helper"

# Ledger D9: backgrounds, borders and gradients are Shoes::Patterns (manual 785-790,
# 2754-2755, 2807-2809), and to_pattern hands one to another background or border,
# which paints with the same colour (manual 2799-2803, 2854-2858).
class TestPattern < NienteTest
  def test_backgrounds_borders_and_gradients_are_patterns_that_paint_others
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $fade = gradient(red, blue)
        $stripe = background tomato
        $edge = border green, strokewidth: 2
        $from_edge = background $edge.to_pattern
        $from_stripe = border $stripe.to_pattern
        $faded = background $fade
        fill $stripe.to_pattern
        $shape = rect 0, 0, 10
      end
    SHOES_APP
      [$fade, $stripe, $edge].each { |pattern| assert_kind_of Shoes::Pattern, pattern }
      assert_same $stripe, $stripe.to_pattern

      assert_equal $edge.stroke, $from_edge.fill, "a border's pattern paints a background"
      assert_equal $stripe.fill, $from_stripe.stroke, "a background's pattern strokes a border"
      assert_same $fade, $faded.fill, "a gradient paints as itself"
      assert_equal $stripe.fill, $shape.fill, "and fill takes a pattern too"
    SHOES_SPEC
  end

  # Border declared strokewidth twice, plain first, so its integer validator never ran.
  def test_border_strokewidth_is_read_as_a_whole_number
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $edge = border red, strokewidth: "3"
      end
    SHOES_APP
      assert_equal 3, $edge.strokewidth
    SHOES_SPEC
  end

  # Shoes 3 strokes a border with its own strokewidth, 1 unless given (shoes_border_draw,
  # s3t_pattern.c:219). The pen's strokewidth used to reach it through the draw context,
  # so a border drawn after `strokewidth 6` art came out 6 px wide.
  def test_a_border_keeps_its_own_strokewidth_and_not_the_pens
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        strokewidth 6
        line 0, 0, 100, 0
        $plain = border red
        $given = border red, strokewidth: 3
        $placed = border red, 4
      end
    SHOES_APP
      assert_equal 1, $plain.strokewidth, "a border given no width is a hairline"
      assert_equal 3, $given.strokewidth
      assert_equal 4, $placed.strokewidth, "the second argument is still its width"
    SHOES_SPEC
  end
end
