# frozen_string_literal: true

require "test_helper"

class TestWebviewImage < ScarpeTest
  def setup
    @url = "http://shoesrb.com/manual/static/shoes-icon.png"
    @default_properties = {
      "shoes_linkable_id" => 1,
      "url" => @url,
    }
    Scarpe::DisplayService.full_reset!
  end

  def teardown
    Scarpe::DisplayService.full_reset!
  end

  def test_renders_image
    img = Scarpe::WebviewImage.new(@default_properties)

    assert_html img.to_html, :img, id: img.html_id, src: @url
  end

  def test_renders_image_with_specified_size
    width = 100
    height = 50
    img = Scarpe::WebviewImage.new(@default_properties.merge(width:, height:))

    assert_html img.to_html, :img, id: img.html_id, src: @url, style: "width:#{width}px;height:#{height}px"
  end

  def test_renders_image_with_specified_position
    top = 1
    left = 5
    img = Scarpe::WebviewImage.new(@default_properties.merge(top:, left:))

    assert_html img.to_html, :img, id: img.html_id, src: @url, style: "top:#{top}px;left:#{left}px;position:absolute"
  end

  def test_renders_image_with_specified_size_and_position
    width = 100
    height = 50
    top = 1
    left = 5
    img = Scarpe::WebviewImage.new(@default_properties.merge(width:, height:, top:, left:))

    assert_html img.to_html,
      :img,
      id: img.html_id,
      src: @url,
      style: "width:#{width}px;height:#{height}px;top:#{top}px;left:#{left}px;position:absolute"
  end

  def test_renders_clickable_image
    target_url = "http://github.com/schwad/scarpe"
    img = Scarpe::WebviewImage.new(@default_properties.merge("click" => target_url))

    assert_equal "<a id=\"#{img.html_id}\" href=\"#{target_url}\">"\
      "<img id=\"#{img.html_id}\" src=\"#{@url}\" />"\
      "</a>",
      img.to_html
  end

  def test_image_size
    url = "http://shoesrb.com/manual/static/shoes-icon.png"
    expected_size = [128, 128]
    img = Scarpe::Image.new(url)
    actual_size = img.size

    assert_equal expected_size, actual_size
  end
end
