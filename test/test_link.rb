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

    assert_html link.to_html, :u, id: link.html_id, onclick: link.handler_js_code("click") do
      "click me"
    end
  end
end
