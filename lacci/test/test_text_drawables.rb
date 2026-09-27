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

  # Manual: ins(text) » Shoes::Ins, a single-underlined fragment (manual.md:2025-2028).
  # It is not a synonym for inscription (DESIGN.md section 10, item 8).
  def test_ins_is_an_underline_fragment
    run_test_niente_code(<<~'SHOES_APP', app_test_code: <<~'SHOES_SPEC')
      Shoes.app do
        @fragment = ins("hard to read")
        para "can be ", @fragment
      end
    SHOES_APP
      fragment = Shoes.APPS[0].instance_variable_get(:@fragment)
      assert_kind_of Shoes::Ins, fragment
      assert_equal "single", fragment.underline
      assert_equal ["can be ", fragment.linkable_id], para.text_items
      assert_equal "can be hard to read", para.text
    SHOES_SPEC
  end
end
