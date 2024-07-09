# frozen_string_literal: true

require_relative "test_helper"

class TestShoesErrors < NienteTest
  def test_drawable_attr_error
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
    Shoes.app do
      button "OK" do
        star 10, 25, "sammy"
      end
    end
    SHOES_APP
    assert_raises Shoes::Errors::InvalidAttributeValueError do
      button().trigger_click
    end
    SHOES_SPEC
  end

  # Niente can no longer test the TooManyInstancesError because it now
  # supports multiple Shoes apps.
  #def test_too_many_instances_error
  #  run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
  #  $ruby_main = self
  #  Shoes.app do
  #  end
  #  SHOES_APP
  #  assert_raises Shoes::Errors::TooManyInstancesError do
  #    $ruby_main.instance_eval do
  #      Shoes.app {}
  #    end
  #  end
  #  SHOES_SPEC
  #end

  def test_drawables_found_errors
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
    Shoes.app do
      button "OK"
      button "Not OK"
    end
    SHOES_APP
    assert_raises Shoes::Errors::MultipleDrawablesFoundError do
      button()
    end
    assert_raises Shoes::Errors::NoDrawablesFoundError do
      edit_line()
    end
    SHOES_SPEC
  end
end
