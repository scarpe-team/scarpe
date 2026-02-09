# frozen_string_literal: true

require "test_helper"

class TestWebviewImage < ScarpeTest
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
    html = img.to_html

    # Check essential attributes
    assert_includes html, "<img"
    assert_includes html, "id=\"#{img.html_id}\""
    assert_includes html, "src=\"#{@url}\""
    # Images now include event handlers
    assert_includes html, "onclick="
    assert_includes html, "onmouseover="
    assert_includes html, "onmouseout="
  end

  def test_renders_image_with_specified_size
    width = 100
    height = 50
    img = Scarpe::Webview::Image.new(@default_properties.merge(width:, height:))
    html = img.to_html

    assert_includes html, "<img"
    assert_includes html, "id=\"#{img.html_id}\""
    assert_includes html, "src=\"#{@url}\""
    assert_includes html, "width:#{width}px"
    assert_includes html, "height:#{height}px"
  end

  def test_renders_image_with_specified_position
    top = 1
    left = 5
    img = Scarpe::Webview::Image.new(@default_properties.merge(top:, left:))
    html = img.to_html

    assert_includes html, "<img"
    assert_includes html, "id=\"#{img.html_id}\""
    assert_includes html, "src=\"#{@url}\""
    assert_includes html, "position:absolute"
    assert_includes html, "top:#{top}px"
    assert_includes html, "left:#{left}px"
  end

  def test_renders_image_with_specified_size_and_position
    width = 100
    height = 50
    top = 1
    left = 5
    img = Scarpe::Webview::Image.new(@default_properties.merge(width:, height:, top:, left:))
    html = img.to_html

    assert_includes html, "<img"
    assert_includes html, "id=\"#{img.html_id}\""
    assert_includes html, "src=\"#{@url}\""
    assert_includes html, "position:absolute"
    assert_includes html, "top:#{top}px"
    assert_includes html, "left:#{left}px"
    assert_includes html, "width:#{width}px"
    assert_includes html, "height:#{height}px"
  end

  def test_renders_image_with_event_handlers
    img = Scarpe::Webview::Image.new(@default_properties)
    html = img.to_html

    # Images have click/hover/leave handlers via JavaScript
    assert_includes html, "onclick=\"scarpeHandler('#{img.html_id}-click')\""
    assert_includes html, "onmouseover=\"scarpeHandler('#{img.html_id}-hover')\""
    assert_includes html, "onmouseout=\"scarpeHandler('#{img.html_id}-leave')\""
  end

  def test_renders_image_with_click_property
    # When a "click" property is set, cursor should be pointer
    img = Scarpe::Webview::Image.new(@default_properties.merge("click" => true))
    html = img.to_html

    assert_includes html, "cursor:pointer"
    assert_includes html, "onclick="
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
