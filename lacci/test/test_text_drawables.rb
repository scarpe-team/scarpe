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

  # Wire contract (d): a style that sets underline or strikethrough to nil or false
  # sends "none", so the display drops a link's own underline (accordion.rb and the
  # menu samples say style(Link, underline: nil)). true means "single" (ledger F6).
  # An underline nobody set stays unset.
  def test_turning_decorations_off_says_none
    run_test_niente_code(<<~'SHOES_APP', app_test_code: <<~'SHOES_SPEC')
      Shoes.app do
        style(Shoes::Link, underline: nil)
        @plain = para "plain"
        @menu = para link("menu")
        @off = para "off", underline: false, strikethrough: nil
        @on = para "on", underline: true
      end
    SHOES_APP
      menu_link = para("@menu").contents.first
      assert_equal "none", menu_link.underline
      assert_equal "none", Niente::DisplayService.instance.query_display_drawable_for(menu_link.linkable_id).instance_variable_get(:@data)["underline"]

      assert_equal ["none", "none"], [para("@off").underline, para("@off").strikethrough]
      assert_equal "single", para("@on").underline
      assert_nil para("@plain").underline
    SHOES_SPEC
  end
end
