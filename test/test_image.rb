# frozen_string_literal: true

require "test_helper"

class TestImage < Minitest::Test
  def setup
    @url = "http://shoesrb.com/manual/static/shoes-icon.png"
  end

  def test_renders_image
    img = Scarpe::Image.new(@url)

    assert_html img.to_html, :img, id: img.html_id, src: @url
  end

  def test_renders_image_with_specified_size
    width = 100
    height = 50
    img = Scarpe::Image.new(@url, width: width, height: height)

    assert_html img.to_html, :img, id: img.html_id, src: @url, style: "width:#{width}px;height:#{height}px"
  end

  def test_renders_image_with_specified_position
    top = 1
    left = 5
    img = Scarpe::Image.new(@url, top: top, left: left)

    assert_html img.to_html, :img, id: img.html_id, src: @url, style: "top:#{top}px;left:#{left}px;position:absolute"
  end

  def test_renders_image_with_specified_size_and_position
    width = 100
    height = 50
    top = 1
    left = 5
    img = Scarpe::Image.new(@url, width: width, height: height, top: top, left: left)

    assert_html img.to_html, :img, id: img.html_id, src: @url, style: "width:#{width}px;height:#{height}px;top:#{top}px;left:#{left}px;position:absolute"
  end

end
