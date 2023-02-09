# frozen_string_literal: true

require "test_helper"

class TestColors < Minitest::Test

  class Dummy
    include Scarpe::Colors
  end

  def test_default_colors_are_accessible_via_methods
    assert_equal [0, 0, 0, 1.0], Dummy.new.black
    assert_equal [255, 255, 255, 1.0], Dummy.new.white
  end

  def test_default_colors_can_accept_alpha
    assert_equal [0, 0, 0, 0.5], Dummy.new.black(0.5)
  end

  def test_gray_accepts_single_value_for_darkness
    assert_equal [0, 0, 0, 1.0], Dummy.new.gray(0)
    assert_equal [255, 255, 255, 1.0], Dummy.new.gray(255)
  end

  def test_gray_accepts_darkness_and_alpha
    assert_equal [0, 0, 0, 0.5], Dummy.new.gray(0, 0.5)
  end

  def test_gray_defaults_to_50_percent_darkness
    assert_equal [128, 128, 128, 1.0], Dummy.new.gray
  end

  def test_rgb_accepts_three_values
    assert_equal [255, 0, 0, 1.0], Dummy.new.rgb(255, 0, 0)
  end

  def test_rgb_accepts_alpha
    assert_equal [255, 0, 0, 0.5], Dummy.new.rgb(255, 0, 0, 0.5)
  end
end
