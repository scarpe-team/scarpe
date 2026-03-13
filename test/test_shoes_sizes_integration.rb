# frozen_string_literal: true
# Integration test to verify the centralized ShoesSizes refactoring

$LOAD_PATH.unshift File.expand_path("../scarpe-components/lib", __dir__)

require "minitest/autorun"
require "scarpe/components/shoes_sizes"
require "scarpe/components/calzini"

class TestShoesSizesIntegration < Minitest::Test
  def setup
    @test_class = Class.new do
      include Scarpe::Components::Calzini
      def html_id; "test-1"; end
      def handler_js_code(event); "test_handler"; end
    end
    @renderer = @test_class.new
  end

  def test_calzini_text_size_uses_centralized_implementation
    # Test that text_size works correctly for all named sizes
    assert_equal 48, @renderer.text_size(:banner)
    assert_equal 34, @renderer.text_size(:title)
    assert_equal 26, @renderer.text_size(:subtitle)
    assert_equal 18, @renderer.text_size(:tagline)
    assert_equal 14, @renderer.text_size(:caption)
    assert_equal 12, @renderer.text_size(:para)
    assert_equal 10, @renderer.text_size(:inscription)
    assert_equal 10, @renderer.text_size(:ins)
  end

  def test_text_size_handles_numeric_values
    assert_equal 42, @renderer.text_size(42)
    assert_equal 15.5, @renderer.text_size(15.5)
  end

  def test_text_size_handles_string_values
    assert_equal 48, @renderer.text_size("banner")
    assert_equal 20, @renderer.text_size("20")
  end

  def test_text_size_delegates_to_shoes_sizes
    # Verify that Calzini's text_size gives the same results as ShoesSizes
    [:banner, :title, :subtitle, :tagline, :caption, :para, :inscription, :ins].each do |size_name|
      assert_equal Scarpe::Components::ShoesSizes.text_size(size_name),
                   @renderer.text_size(size_name),
                   "Mismatch for size #{size_name}"
    end
  end

  def test_sizes_constant_is_frozen
    assert Scarpe::Components::ShoesSizes::SIZES.frozen?,
           "ShoesSizes::SIZES should be frozen"
  end

  def test_centralized_sizes_has_all_expected_keys
    sizes = Scarpe::Components::ShoesSizes::SIZES
    expected_keys = [:inscription, :ins, :para, :caption, :tagline, :subtitle, :title, :banner]
    assert_equal expected_keys.sort, sizes.keys.sort,
                 "ShoesSizes::SIZES should have all expected size names"
  end

  def test_centralized_text_size_method_exists
    assert_respond_to Scarpe::Components::ShoesSizes, :text_size,
                      "ShoesSizes should have a text_size class method"
  end
end
