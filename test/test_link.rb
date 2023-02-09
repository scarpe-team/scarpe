# frozen_string_literal: true

require "test_helper"

class TestEditBox < Minitest::Test
  def setup
    app = Minitest::Mock.new
    Scarpe::Widget.set_document_root(app)
    app.expect :bind, nil, [Object]
  end

  def test_link_with_a_block
    link = Scarpe::Link.new("click me") { "thanks" }
    expected_attributes = {
      id: link.html_id,
      style: "color:blue",
      onmouseover: "this.style.color='darkblue'",
      onmouseout: "this.style.color='blue';",
      onclick: link.handler_js_code("click")
    }

    assert_html link.to_html, :u, **expected_attributes do
      "click me"
    end
  end

  def test_link_with_a_url
    link = Scarpe::Link.new("click me", click: "http://github.com/schwad/scarpe")

    assert_html link.to_html, :a, href: "http://github.com/schwad/scarpe" do
      "click me"
    end
  end
end
