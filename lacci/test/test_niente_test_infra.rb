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
end
