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
    stack = Scarpe::Webview::Stack.new(@default_properties.merge("height" => 25))

    assert_includes stack.to_html, "height:25px"
  end



  #def test_it_can_have_a_background
  #  stack = Scarpe::Stack.new do
  #    background "red"
  #  end
  #
  #  assert_includes? stack.to_html, "background:red"
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

class TestStackMethods < ShoesSpecLoggedTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

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
      main = stack("@slot")

      assert_equal 1, main.children.size

      b_clear = button("@b_clear")
      b_add = button("@b_add")

      b_add.trigger_click
      b_add.trigger_click
      b_add.trigger_click
      assert_equal 4, main.children.size

      b_clear.trigger_click
      assert_equal 0, main.children.size
    TEST_CODE
  end
end
