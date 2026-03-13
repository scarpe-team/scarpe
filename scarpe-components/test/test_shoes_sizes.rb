# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "scarpe/components/shoes_sizes"

class TestShoesSizes < Minitest::Test
  def test_sizes_constant_exists
    assert_kind_of Hash, Scarpe::Components::ShoesSizes::SIZES
  end

  def test_sizes_is_frozen
    assert Scarpe::Components::ShoesSizes::SIZES.frozen?
  end

  def test_inscription_size
    assert_equal 10, Scarpe::Components::ShoesSizes::SIZES[:inscription]
  end

  def test_ins_size
    assert_equal 10, Scarpe::Components::ShoesSizes::SIZES[:ins]
  end

  def test_para_size
    assert_equal 12, Scarpe::Components::ShoesSizes::SIZES[:para]
  end

  def test_caption_size
    assert_equal 14, Scarpe::Components::ShoesSizes::SIZES[:caption]
  end

  def test_tagline_size
    assert_equal 18, Scarpe::Components::ShoesSizes::SIZES[:tagline]
  end

  def test_subtitle_size
    assert_equal 26, Scarpe::Components::ShoesSizes::SIZES[:subtitle]
  end

  def test_title_size
    assert_equal 34, Scarpe::Components::ShoesSizes::SIZES[:title]
  end

  def test_banner_size
    assert_equal 48, Scarpe::Components::ShoesSizes::SIZES[:banner]
  end

  def test_all_expected_sizes_present
    expected_keys = [:inscription, :ins, :para, :caption, :tagline, :subtitle, :title, :banner]
    assert_equal expected_keys.sort, Scarpe::Components::ShoesSizes::SIZES.keys.sort
  end

  def test_text_size_with_numeric
    assert_equal 42, Scarpe::Components::ShoesSizes.text_size(42)
  end

  def test_text_size_with_float
    assert_equal 12.5, Scarpe::Components::ShoesSizes.text_size(12.5)
  end

  def test_text_size_with_symbol
    assert_equal 48, Scarpe::Components::ShoesSizes.text_size(:banner)
  end

  def test_text_size_with_symbol_para
    assert_equal 12, Scarpe::Components::ShoesSizes.text_size(:para)
  end

  def test_text_size_with_string_name
    assert_equal 48, Scarpe::Components::ShoesSizes.text_size("banner")
  end

  def test_text_size_with_string_number
    assert_equal 20, Scarpe::Components::ShoesSizes.text_size("20")
  end

  def test_text_size_with_unknown_symbol
    assert_nil Scarpe::Components::ShoesSizes.text_size(:unknown)
  end

  def test_text_size_with_unknown_string
    # Unknown string names get converted via to_i which returns 0
    assert_equal 0, Scarpe::Components::ShoesSizes.text_size("unknown")
  end

  def test_text_size_raises_for_unexpected_type
    assert_raises(RuntimeError) do
      Scarpe::Components::ShoesSizes.text_size([1, 2, 3])
    end
  end

  def test_sizes_are_in_ascending_order
    sizes = Scarpe::Components::ShoesSizes::SIZES
    ordered_names = [:inscription, :para, :caption, :tagline, :subtitle, :title, :banner]
    ordered_values = ordered_names.map { |name| sizes[name] }
    assert_equal ordered_values, ordered_values.sort
  end

  def test_ins_matches_inscription
    sizes = Scarpe::Components::ShoesSizes::SIZES
    assert_equal sizes[:inscription], sizes[:ins]
  end
end
