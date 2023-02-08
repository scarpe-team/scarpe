# frozen_string_literal: true

require "test_helper"

class TestPara < Minitest::Test
  def setup
    @app = Minitest::Mock.new
    @app.expect :append, nil, [String]
    @app.expect :bind, nil, [Integer]
  end

  def test_renders_a_link_within_a_para
    para = Scarpe::Para.new(@app, "Hello")
    link = Scarpe::Link.new(@app, "Click me") { para "World!" }

    result = link.render(para)

    assert_equal "<u id=\"#{link.object_id}\" onclick=\"scarpeHandler(#{link.function_name})\">Click me</u>", result
  end
  g
  def test_renders_a_link_with_a_url
    my_website = "http://github.com/schwad/scarpe"
    para = Scarpe::Para.new(@app, "Hello")
    link = Scarpe::Link.new(@app, "Click me", click: my_website)

    result = link.render(para)

    assert_equal "<a id=\"#{link.object_id}\" href=\"#{my_website}\">Click me</a>", result
  end

  def test_rendering_a_link_outside_a_paragraph_raises_exception
    link = Scarpe::Link.new(@app, "Click me!") { para "Thanks." }

    assert_raises(Scarpe::Link::InvalidParentError) do
      link.render(self)
    end
  end

  def test_clicking_the_button_calls_the_passed_block
    link = Scarpe::Link.new(@app, "Click me") { "Ouch!!" }

    link.click

    assert_equal "Ouch!!", link.click
  end
end
