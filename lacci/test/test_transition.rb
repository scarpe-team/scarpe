# frozen_string_literal: true

require_relative "test_helper"

class TestTransition < NienteTest
  def test_unsupported_display_reports_an_error_before_changing_styles
    run_test_niente_code(<<~APP, app_test_code: <<~TEST)
      Shoes.app { @panel = stack(opacity: 0.7) { para "Hello" } }
    APP
      panel = Shoes.APPS.first.instance_variable_get(:@panel)
      called = false
      assert_raises(Shoes::Error) { panel.transition(opacity: 0) { called = true } }
      assert_equal 0.7, panel.opacity
      refute called
    TEST
  end
end
