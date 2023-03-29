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
