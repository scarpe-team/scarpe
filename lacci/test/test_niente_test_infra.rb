# frozen_string_literal: true

require_relative "test_helper"

class TestNienteTestInfra < NienteTest
  def test_app_fail_in_test
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC, expect_process_fail: true)
      Shoes.app do
        @b = button "OK"
        raise "ERROR!"
      end
    SHOES_APP
      assert_equal true, true
    SHOES_SPEC
  end

  def test_app_fail_in_spec
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC, expect_minitest_exception: true)
      Shoes.app do
        @b = button "OK"
      end
    SHOES_APP
      raise "ERROR!"
    SHOES_SPEC
  end

  def test_multi_app_find
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @b = button "OK"
      end
      Shoes.app do
        @b2 = button "Nope"
      end
    SHOES_APP
      assert_equal "OK", button("@b").text
      assert_equal "Nope", button("@b2").text
    SHOES_SPEC
  end
end
