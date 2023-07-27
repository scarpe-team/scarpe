# frozen_string_literal: true

require "test_helper"

class TestWebviewStack < Minitest::Test
  def setup
    @default_properties = {
      "height" => 200,
      "width" => 300,
      "margin" => 3,
      "padding" => 4,
      "shoes_linkable_id" => 1,
    }
  end

  def test_it_accepts_a_height
    stack = Scarpe::WebviewStack.new(@default_properties.merge("height" => 25))

    assert(stack.to_html.include?("height:25px"))
  end

  def test_it_accepts_margin
    stack = Scarpe::WebviewStack.new(@default_properties.merge("margin" => 25))

    assert(stack.to_html.include?("margin:25px"))
  end

  def test_it_accepts_margin_array
    stack = Scarpe::WebviewStack.new(@default_properties.merge("margin" => [1, 2, 3, 4]))

    assert(stack.to_html.include?("margin-left:1px;margin-right:2px;margin-top:3px;margin-bottom:4px"))
  end

  def test_it_accepts_margin_hash
    stack = Scarpe::WebviewStack.new(@default_properties.merge("margin" => { left: 1, bottom: 4 }))

    assert(stack.to_html.include?("margin-left:1px;margin-bottom:4px"))
  end

  #def test_it_can_have_a_background
  #  stack = Scarpe::Stack.new do
  #    background "red"
  #  end
  #
  #  assert(stack.to_html.include?("background:red"))
  #end

  #def test_it_can_have_a_border
  #  stack = Scarpe::Stack.new do
  #    border "#DDD".."#AAA", strokewidth: 10, curve: 12
  #  end
  #
  #  assert(stack.to_html.include?("border-style:solid;"))
  #  assert(stack.to_html.include?("border-width:10px;"))
  #  assert(stack.to_html.include?("border-image:linear-gradient(45deg, #DDD, #AAA) 1;"))
  #end

  #def test_it_can_have_a_gradient_border_and_background
  #  stack = Scarpe::Stack.new do
  #    border "#DDD".."#AAA"
  #    background "#AAA".."#DDD"
  #  end
  #
  #  assert(stack.to_html.include?("border-image:linear-gradient(45deg, #DDD, #AAA) 1;"))
  #  assert(stack.to_html.include?("background:linear-gradient(45deg, #AAA, #DDD);"))
  #end
end

class TestStackMethods < LoggedScarpeTest
  def test_stack_clear_append
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        @slot = stack do
          para "Hello World"
        end
        @b_clear = button("Clear") { @slot.clear }
        @b_add = button("Add") { @slot.append { para "Woot!" } }
      end
    SCARPE_APP
      on_heartbeat do
        main = stack("@slot")

        assert_equal 1, main.children.size

        b_clear = button("@b_clear")
        b_add = button("@b_add")
        b_clear_js = b_clear.display.handler_js_code("click")
        b_add_js = b_add.display.handler_js_code("click")

        query_js_value(b_add_js)
        query_js_value(b_add_js)
        query_js_value(b_add_js)
        wait fully_updated
        assert_equal 4, main.children.size

        query_js_value(b_clear_js) # Run the click-event code
        wait fully_updated
        assert_equal 0, main.children.size

        test_finished
      end
    TEST_CODE
  end
end
