# frozen_string_literal: true

require "test_helper"

class TestImage < Minitest::Test
  def setup
    @url = "http://shoesrb.com/manual/static/shoes-icon.png"
  end

  def test_renders_image
    img = Scarpe::Image.new(@url)

    assert_equal "<img id=\"#{img.html_id}\" src=\"#{@url}\" />", img.to_html
  end

  def test_renders_image_with_specified_size
    width = 100
    height = 50
    img = Scarpe::Image.new(@url, width:, height:)

    assert_equal "<img id=\"#{img.html_id}\" src=\"#{@url}\" style=\"width:#{width}px;height:#{height}px\" />", img.to_html
  end

  def test_renders_image_with_specified_position
    top = 1
    left = 5
    img = Scarpe::Image.new(@url, top:, left:)

    assert_equal "<img id=\"#{img.html_id}\" src=\"#{@url}\" style=\"top:#{top}px;left:#{left}px;position:absolute\" />", img.to_html
  end

  def test_renders_image_with_specified_size_and_position
    width = 100
    height = 50
    top = 1
    left = 5
    img = Scarpe::Image.new(@url, width:, height:, top:, left:)

    assert_equal "<img id=\"#{img.html_id}\" src=\"#{@url}\" style=\"width:#{width}px;height:#{height}px;top:#{top}px;left:#{left}px;position:absolute\" />", img.to_html
  end

  def test_renders_clickable_image
    target_url = "http://github.com/schwad/scarpe"
    img = Scarpe::Image.new(@url, click: target_url)

    assert_equal "<a id=\"#{img.html_id}\" href=\"#{target_url}\">"\
                   "<img id=\"#{img.html_id}\" src=\"#{@url}\" />"\
                 "</a>", img.to_html
  end
end
