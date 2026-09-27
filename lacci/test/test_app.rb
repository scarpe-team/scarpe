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

  # Ledger A3: Shoes.app, window and dialog return the new Shoes::App (manual 859,
  # 1958-1961), where Shoes.app ended with nil.
  def test_shoes_app_window_and_dialog_return_the_app
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      $main = Shoes.app do
        $window = window(title: "second") { para "two" }
        $dialog = dialog(title: "third") { para "three" }
      end
    SHOES_APP
      assert_equal Shoes.APPS, [$main, $window, $dialog]
      assert_same $main, $window.owner
    SHOES_SPEC
  end

  # Ledger D6: background takes an :angle for its gradient (manual 1073-1079).
  def test_a_backgrounds_angle_turns_its_gradient
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @turned = background red..blue, angle: 90
      end
    SHOES_APP
      turned = background("@turned")
      assert_equal 90, turned.style[:angle]
      assert_equal 90, turned.fill.angle, "the angle travels with the gradient itself"
    SHOES_SPEC
  end
end
