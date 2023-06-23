# frozen_string_literal: true

require "test_helper"

# Link display properties: text, click, has_block

class TestWebviewLink < ScarpeWebviewTest
  def setup
    @default_properties = {
      "text" => "click here",
      "click" => "#",
      "has_block" => false,
      "shoes_linkable_id" => 1,
    }
  end

  def with_mocked_binding(&block)
    @mocked_disp_service = Minitest::Mock.new
    @mocked_doc_root = Minitest::Mock.new
    @mocked_disp_service.expect(:doc_root, @mocked_doc_root)
    @mocked_doc_root.expect(:bind, nil, [String])

    Scarpe::WebviewDisplayService.stub(:instance, @mocked_disp_service, &block)

    @mocked_disp_service.verify
    @mocked_doc_root.verify
  end

  def test_link_with_url
    with_mocked_binding do
      link = Scarpe::WebviewLink.new(@default_properties.merge("click" => "https://www.google.com"))

      assert_html link.to_html, :a, id: link.html_id, href: "https://www.google.com" do
        "click here"
      end
    end
  end

  def test_link_with_block
    with_mocked_binding do
      link = Scarpe::WebviewLink.new(@default_properties.merge("has_block" => true))

      assert_html link.to_html, :a, id: link.html_id, href: "#", onclick: link.handler_js_code("click") do
        "click here"
      end
    end
  end
end
