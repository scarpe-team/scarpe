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
end
