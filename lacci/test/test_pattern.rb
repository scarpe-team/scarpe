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
end
