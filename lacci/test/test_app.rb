# frozen_string_literal: true

require_relative "test_helper"

class TestApp < NienteTest
  # Ledger A1, ruled by Q1 (27 Sep 2026): Shoes 3 and Shoes 4 open 600x500, titled "Shoes".
  def test_an_app_with_no_size_opens_at_the_shoes_default
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app { para "sized by default" }
    SHOES_APP
      app = Shoes.APPS.first
      assert_equal [600, 500], [app.width, app.height]
      assert_equal "Shoes", app.style[:title]
    SHOES_SPEC
  end
end
