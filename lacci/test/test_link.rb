# frozen_string_literal: true

require_relative "test_helper"

# DESIGN.md section 10, item 5. Manual: link(text, click: proc or string)
# (manual.md:2034); the block gets the link (research 06 ledger F8).
class TestLink < NienteTest
  # Text fragments have no slot parent, so the finders cannot reach them.
  FIND_GO = "go = Niente::ShoesSpecProxy.new(Shoes.APPS[0].instance_variable_get(:@go))"

  def test_click_proc_fires
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @clicked = []
        @go = link("go", click: proc { |l| @clicked << l.text })
        para @go
      end
    SHOES_APP
      #{FIND_GO}
      go.trigger_click
      assert_equal ["go"], Shoes.APPS[0].instance_variable_get(:@clicked)
      assert_equal true, go.display.instance_variable_get(:@data)["has_block"]
      refute_kind_of Proc, go.display.instance_variable_get(:@data)["click"]
    SHOES_SPEC
  end

  def test_click_method_turns_on_has_block
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @clicked = []
        @go = link("go")
        para @go
        @go.click { |l| @clicked << l.text }
      end
    SHOES_APP
      #{FIND_GO}
      assert_equal true, go.display.instance_variable_get(:@has_block)
      go.trigger_click
      assert_equal ["go"], Shoes.APPS[0].instance_variable_get(:@clicked)
    SHOES_SPEC
  end
end
