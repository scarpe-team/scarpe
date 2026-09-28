# frozen_string_literal: true

require "test_helper"

class TestColors < Minitest::Test
  class Dummy
    include Shoes::Colors
  end

  # Ledger D1: colours are Shoes::Color objects with red, green, blue and alpha, and
  # still Arrays, so destructuring and comparing keep working (manual 790-834).
  def test_colours_are_shoes_colors_that_still_act_as_arrays
    violet = Shoes.rgb(138, 43, 226)
    assert_kind_of Shoes::Color, violet
    assert_equal [138, 43, 226, 255], [violet.red, violet.green, violet.blue, violet.alpha]
    assert_kind_of Shoes::Color, Dummy.new.blue
    assert_kind_of Shoes::Color, Shoes.gray(10)

    r, g, b, a = violet
    assert_equal [138, 43, 226, 255], [r, g, b, a]
    assert_equal [138, 43, 226, 255], violet
    assert_equal [255, 136, 0, 255], Shoes::Color.from("#ff8800")
    assert_nil Shoes::Color.from(nil)
  end

  def test_default_colors_are_accessible_via_methods
    assert_equal [0, 0, 0, 255], Dummy.new.black
    assert_equal [255, 255, 255, 255], Dummy.new.white
  end

  def test_default_colors_can_accept_alpha
    assert_equal [0, 0, 0, 128], Dummy.new.black(0.5)
    assert_equal [255, 0, 0, 51], Dummy.new.red(0.2)
    assert_equal [0, 0, 0, 100], Dummy.new.black(100)
  end

  def test_gray_accepts_single_value_for_darkness
    assert_equal [0, 0, 0, 255], Dummy.new.gray(0)
    assert_equal [255, 255, 255, 255], Dummy.new.gray(255)
  end

  def test_gray_accepts_darkness_and_alpha
    assert_equal [0, 0, 0, 128], Dummy.new.gray(0, 128)
  end

  def test_gray_defaults_to_50_percent_darkness
    assert_equal [128, 128, 128, 255], Dummy.new.gray
  end

  def test_rgb_accepts_three_values
    assert_equal [255, 0, 0, 255], Dummy.new.rgb(255, 0, 0)
  end

  def test_rgb_accepts_alpha
    assert_equal [255, 0, 0, 128], Dummy.new.rgb(255, 0, 0, 128)
  end

  # Manual: rgb(0, 0.4, 0) is dark green (manual.md:827-832). Shoes 3 reads
  # each component on its own: a Float is a fraction of 255, an Integer is itself.
  def test_rgb_decides_int_or_float_per_component
    assert_equal [0, 102, 0, 255], Dummy.new.rgb(0, 0.4, 0)
    assert_equal [255, 0, 0, 77], Dummy.new.rgb(255, 0, 0, 0.3)
    assert_equal [128, 51, 26, 255], Dummy.new.rgb(0.5, 0.2, 0.1)
    assert_equal [255, 255, 255, 255], Dummy.new.rgb(1.0, 1.0, 1.0)
  end

  def test_gray_accepts_a_fraction
    assert_equal [128, 128, 128, 255], Dummy.new.gray(0.5)
  end

  # Shoes 3 expands each short hex digit by 17, so #DFA is #DDFFAA.
  def test_short_hex_expands_each_digit_by_17
    assert_equal [221, 255, 170, 255], Dummy.new.to_rgb("#DFA")
    assert_equal [170, 187, 204, 255], Dummy.new.to_rgb("#abc")
    assert_equal [255, 255, 255, 255], Dummy.new.to_rgb("#fff")
  end

  # Ledger D6: gradients run top to bottom unless given an angle (manual 1073-1079),
  # and each end keeps its alpha.
  def test_gradients_run_top_to_bottom_and_keep_alpha
    fade = Dummy.new.gradient(Dummy.new.red(0.5), "#00f")
    assert_equal 0, fade.angle
    assert_equal ["rgba(255,0,0,0.502)", "rgba(0,0,255,1.0)"], [fade.color1, fade.color2]
    assert_equal 90, Dummy.new.gradient("#f00", "#00f", angle: 90).angle
  end

  # Ledger D4: rgb, gray and gradient are built-ins, callable from any object
  # (manual 785-834), not only from drawables.
  class Palette
    def colours
      [rgb(138, 43, 226), gray(1.0), gradient("#000", "#fff")]
    end
  end

  def test_rgb_gray_and_gradient_work_anywhere
    violet, white, fade = Palette.new.colours
    assert_equal [138, 43, 226, 255], violet
    assert_equal [255, 255, 255, 255], white
    assert_kind_of Shoes::Colors::Gradient, fade
    refute Object.new.respond_to?(:red), "named colours stay on drawables"
  end
end
