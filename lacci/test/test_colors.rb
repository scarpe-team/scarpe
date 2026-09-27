# frozen_string_literal: true

require "test_helper"

class TestColors < Minitest::Test
  class Dummy
    include Shoes::Colors
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
end
