# frozen_string_literal: true

require "test_helper"

class TestLink < Minitest::Test
  def setup
    app = Minitest::Mock.new
    Scarpe::Widget.document_root = app
    app.expect :bind, nil, [Object]
  end

  def test_link_with_a_block
    link = Scarpe::Link.new("click me") { "thanks" }

    assert_html link.to_html, :a, id: link.html_id, href: "#", onclick: link.handler_js_code("click") do
      "click me"
    end
  end

  def test_link_with_a_url
    link = Scarpe::Link.new("click me", click: "http://github.com/schwad/scarpe")

    assert_html link.to_html, :a, id: link.html_id, href: "http://github.com/schwad/scarpe" do
      "click me"
    end
  end
end
