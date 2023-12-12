# frozen_string_literal: true

require "test_helper"

class TestWebviewLink < ScarpeTest
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
    @mocked_app = Minitest::Mock.new
    @mocked_disp_service.expect(:app, @mocked_app)
    @mocked_app.expect(:bind, nil, [String])

    Scarpe::Webview::DisplayService.stub(:instance, @mocked_disp_service, &block)

    @mocked_disp_service.verify
    @mocked_app.verify
  end

  def test_link_with_url
    with_mocked_binding do
      link = Scarpe::Webview::Link.new(@default_properties.merge("click" => "https://www.google.com"))

      assert_html link.to_html, :a, id: link.html_id, href: "https://www.google.com" do
        "click here"
      end
    end
  end

  def test_link_with_block
    with_mocked_binding do
      link = Scarpe::Webview::Link.new(@default_properties.merge("has_block" => true))

      assert_html link.to_html, :a, id: link.html_id, href: "#", onclick: link.handler_js_code("click") do
        "click here"
      end
    end
  end
end
