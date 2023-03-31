# frozen_string_literal: true

require "test_helper"

TEST_VALUES = {}

# This method of testing starts up a Scarpe app with no display service
# that runs in the same process as the test.
class TestNoDisplayImage < Minitest::Test
  def setup
    TEST_VALUES.clear
    @url = "http://shoesrb.com/manual/static/shoes-icon.png"
  end

  def test_image
    test_scarpe_code_no_display(<<~SCARPE_APP, <<~'TEST_CODE')
      Shoes.app do
        image #{@url.inspect}
      end
    SCARPE_APP
      the_app = self
      on_next_heartbeat do
        image = find_widgets_by(Scarpe::Image)[0]
        TEST_VALUES[:url] = image.url
        the_app.destroy
      end
    TEST_CODE
    assert_equal @url, TEST_VALUES[:url]
  end
end

class TestWebviewImage < Minitest::Test
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
end
