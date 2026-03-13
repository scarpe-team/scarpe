# frozen_string_literal: true

require_relative "test_helper"

class TestShoesStyleRegistration < Minitest::Test
  def test_duplicate_style_same_feature_and_validator_warns
    klass = build_test_drawable_class("Warn")
    validator = proc { |val| Integer(val) }

    klass.shoes_style(:repeatable, feature: :fancy, &validator)

    _out, err = capture_io do
      klass.shoes_style(:repeatable, feature: :fancy, &validator)
    end

    assert_match(/Duplicate Shoes style "repeatable"/i, err)
    assert_equal 1, klass.shoes_style_hashes.count { |h| h[:name] == "repeatable" }
  end

  def test_duplicate_style_with_different_feature_raises
    klass = build_test_drawable_class("FeatureMismatch")
    validator = proc { |val| Integer(val) }

    klass.shoes_style(:repeatable, feature: :first, &validator)

    error = assert_raises(Shoes::Errors::DuplicateRegisteredShoesStyleError) do
      klass.shoes_style(:repeatable, feature: :second, &validator)
    end

    assert_match(/mismatched registration/i, error.message)
  end

  def test_duplicate_style_with_different_validator_raises
    klass = build_test_drawable_class("ValidatorMismatch")

    klass.shoes_style(:repeatable, feature: :fancy) { |val| Integer(val) }

    error = assert_raises(Shoes::Errors::DuplicateRegisteredShoesStyleError) do
      klass.shoes_style(:repeatable, feature: :fancy) { |val| Float(val) }
    end

    assert_match(/mismatched registration/i, error.message)
  end

  private

  def build_test_drawable_class(suffix)
    const_name = "DrawableForStyleRegistration#{suffix}#{rand(100_000)}"
    klass = Class.new(Shoes::Drawable)
    Shoes.const_set(const_name, klass)
    klass
  end
end
