# frozen_string_literal: true

require "test_helper"

class TestWebviewImage < ScarpeWebviewTest
  def setup
    @url = "http://shoesrb.com/manual/static/shoes-icon.png"
    @default_properties = {
      "shoes_linkable_id" => 1,
      "url" => @url,
    }
    Shoes::DisplayService.full_reset!
  end

  def teardown
    Shoes::DisplayService.full_reset!
  end

  def test_renders_image
    img = Scarpe::Webview::Image.new(@default_properties)

    assert_contains_html img.to_html, :img, id: img.html_id, src: @url
  end

  def test_renders_image_with_specified_size
    width = 100
    height = 50
    img = Scarpe::Webview::Image.new(@default_properties.merge(width:, height:))

    assert_contains_html img.to_html, :img, id: img.html_id, src: @url, style: "width:#{width}px;height:#{height}px"
  end

  def test_renders_image_with_specified_position
    top = 1
    left = 5
    img = Scarpe::Webview::Image.new(@default_properties.merge(top:, left:))

    assert_contains_html img.to_html, :img, id: img.html_id, src: @url, style: "top:#{top}px;left:#{left}px;position:absolute"
  end

  def test_renders_image_with_specified_size_and_position
    width = 100
    height = 50
    top = 1
    left = 5
    img = Scarpe::Webview::Image.new(@default_properties.merge(width:, height:, top:, left:))

    assert_contains_html img.to_html,
      :img,
      id: img.html_id,
      src: @url,
      style: "width:#{width}px;height:#{height}px;top:#{top}px;left:#{left}px;position:absolute"
  end

  def test_renders_clickable_image
    target_url = "http://github.com/schwad/scarpe"
    img = Scarpe::Webview::Image.new(@default_properties.merge("click" => target_url))

    assert_includes img.to_html, "<a id=\"#{img.html_id}\" href=\"#{target_url}\">"\
      "<img id=\"#{img.html_id}\" src=\"#{@url}\" />"\
      "</a>"
  end
end

class TestImageShoesSpec < ShoesSpecLoggedTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

  def test_image_size
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        image "http://shoesrb.com/manual/static/shoes-icon.png"
      end
    SCARPE_APP
      assert_equal [128, 128], image().size
    TEST_CODE
  end
end
