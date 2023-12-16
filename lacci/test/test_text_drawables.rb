# frozen_string_literal: true

require_relative "test_helper"

class TestTextDrawables < NienteTest
  def test_simple_button
    run_test_niente_code(<<~'SHOES_APP', app_test_code: <<~'SHOES_SPEC')
      Shoes.app do
        para "These are ", em("emphatically"), " ", strong("strongly"), " text drawables!"
      end
    SHOES_APP
      assert_equal "These are emphatically strongly text drawables!", para.text

      # Test that Lacci has set parents properly
      assert_equal Shoes::DocumentRoot, para.parent.class
      assert_equal [Shoes::Para], para.parent.contents.map(&:class)

      # Test that Niente has set parents properly
      assert_equal "DocumentRoot", para().display.parent.shoes_type
      assert_equal ["Para"], document_root.display.children.map(&:shoes_type), "Doc root should have only para as a child!"
    SHOES_SPEC
  end
end
