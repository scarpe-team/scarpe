# frozen_string_literal: true

require_relative "test_helper"

class TestLacci < NienteTest
  def test_simple_button_click
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @b = button "OK" do
          @b.text = "Yup"
        end
      end
    SHOES_APP
      button().trigger_click
      assert_equal "Yup", button().text
    SHOES_SPEC
  end

  def test_positional_default_values
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        star 15, 35
      end
    SHOES_APP
      s = star()
      assert_equal 10, s.points
      assert_equal 50, s.inner
    SHOES_SPEC
  end

  def test_positional_args
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        star 10, 25, 8 # Leave outer and inner as default
      end
    SHOES_APP
      s = star()
      assert_equal 10, s.left
      assert_equal 25, s.top
      assert_equal 8, s.points
      assert_equal 50, s.inner
    SHOES_SPEC
  end

  def test_keyword_args
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        star 5, 6, points: 8, inner: 30
      end
    SHOES_APP
      s = star()
      assert_equal 5, s.left
      assert_equal 6, s.top
      assert_equal 8, s.points
      assert_equal 100, s.outer
      assert_equal 30, s.inner
    SHOES_SPEC
  end

  def test_too_many_positional_args
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s = stack {}
      end
    SHOES_APP
      s = stack("@s")
      assert_raises Shoes::Errors::BadArgumentListError do
        s.star 5, 6, 7, 8, 9, 10, 11
      end
    SHOES_SPEC
  end

  def test_too_few_positional_args
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s = stack {}
      end
    SHOES_APP
      s = stack("@s")
      assert_raises Shoes::Errors::BadArgumentListError do
        s.star 5
      end
    SHOES_SPEC
  end
end
