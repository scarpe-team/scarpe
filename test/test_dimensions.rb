# frozen_string_literal: true

require "test_helper"

class TestDimensions < Minitest::Test
  def test_no_value_returns_nil
    assert_nil ::Scarpe::Dimensions.length(nil)
  end

  def test_integer_value_returns_px
    assert_equal "100px", ::Scarpe::Dimensions.length(100)
  end

  def test_negative_integer_value_returns_calc
    assert_equal "calc(100% - 100px)", ::Scarpe::Dimensions.length(-100)
  end

  def test_float_value_returns_percent
    assert_equal "100.0%", ::Scarpe::Dimensions.length(1.0)
  end

  def test_otherwise_you_get_what_you_give
    assert_equal "banana", ::Scarpe::Dimensions.length("banana")
  end
end
