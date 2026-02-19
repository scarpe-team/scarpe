# frozen_string_literal: true

require_relative "test_helper"

class TestPluralFinders < NienteTest
  def test_buttons_returns_all_buttons
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @b1 = button "Button One"
        @b2 = button "Button Two"
        @b3 = button "Button Three"
      end
    SHOES_APP
      all_buttons = buttons
      assert_equal 3, all_buttons.size
      assert all_buttons.all? { |b| b.is_a?(Niente::ShoesSpecProxy) }
    SHOES_SPEC
  end

  def test_paras_returns_all_paras
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p1 = para "Para One"
        @p2 = para "Para Two"
      end
    SHOES_APP
      all_paras = paras
      assert_equal 2, all_paras.size
    SHOES_SPEC
  end

  def test_plural_finder_with_variable_filter
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @b1 = button "Button One"
        @b2 = button "Other"
      end
    SHOES_APP
      # Filter by variable name - should return just that one
      filtered = buttons("@b1")
      assert_equal 1, filtered.size
      assert_equal "Button One", filtered[0].text
    SHOES_SPEC
  end

  def test_plural_finder_empty_result_bad_variable
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @b1 = button "Button One"
      end
    SHOES_APP
      # Non-existent variable returns empty array
      no_match = buttons("@nonexistent")
      assert_equal 0, no_match.size
      assert_equal [], no_match
    SHOES_SPEC
  end

  def test_drawables_plural
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @b1 = button "One"
        @b2 = button "Two"
        @p1 = para "Text"
      end
    SHOES_APP
      all_buttons = drawables(Shoes::Button)
      assert_equal 2, all_buttons.size
    SHOES_SPEC
  end

  def test_singular_still_works
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @b1 = button "Only One"
      end
    SHOES_APP
      b = button("@b1")
      assert_equal "Only One", b.text
    SHOES_SPEC
  end
end
