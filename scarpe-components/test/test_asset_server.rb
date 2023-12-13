# frozen_string_literal: true

require_relative "test_helper"

require "scarpe/components/asset_server"

class TestAssetServer < Minitest::Test
  def teardown
    @server = nil # Don't keep the same server object from run to run, just in case
  end

  def fake_server
    # We don't need to check HTTP connections, we just want to generate URLs
    @server ||= Scarpe::Components::AssetServer.new port: 4444, app_dir: __dir__, never_start_server: true
  end

  def weird_dir_server
    # Use a deeper app root to test files outside the app's directory
    @server ||= Scarpe::Components::AssetServer.new port: 4444, app_dir: "#{__dir__}/subdir", never_start_server: true
  end

  def test_small_image_explicit_data_url
    url = fake_server.asset_url("#{__dir__}/assets/little-image.png", url_type: :data)
    assert url.start_with?("data:image/png;base64,"), "Data URL for image should start with image/png! #{url.inspect}"
  end

  def test_small_css_explicit_data_url
    url = fake_server.asset_url("#{__dir__}/assets/little-stylesheet.css", url_type: :data)
    assert url.start_with?("data:text/css;base64,"), "Data URL for CSS should start with text/css! #{url.inspect}"
  end

  def test_small_css_auto_data_url
    url = fake_server.asset_url("#{__dir__}/assets/little-stylesheet.css")
    assert url.start_with?("data:text/css;base64,"), "Small CSS files should get a data URL by default! #{url.inspect}"
  end

  def test_small_css_explicit_app_dir_asset_url
    url = fake_server.asset_url("#{__dir__}/assets/little-stylesheet.css", url_type: :asset)
    assert_equal "http://127.0.0.1:4444/app/assets/little-stylesheet.css", url, "Small CSS files should get an asset URL by request!"
  end

  def test_small_css_explicit_component_asset_url
    url = weird_dir_server.asset_url("#{__dir__}/assets/little-stylesheet.css", url_type: :asset)
    assert_equal "http://127.0.0.1:4444/comp/test/assets/little-stylesheet.css", url, "Small CSS files should get an asset URL by request!"
  end

  def test_large_app_file_auto_asset_url
    url = fake_server.asset_url("#{__dir__}/assets/big-image.png")
    assert_equal "http://127.0.0.1:4444/app/assets/big-image.png", url, "Big image files should get an asset URL by default!"
  end

  def test_large_app_file_explicit_asset_url
    url = fake_server.asset_url("#{__dir__}/assets/big-image.png", url_type: :asset)
    assert_equal "http://127.0.0.1:4444/app/assets/big-image.png", url, "Big image files should get an asset URL by default!"
  end

  def test_large_app_file_explicit_data_url
    url = fake_server.asset_url("#{__dir__}/assets/big-image.png", url_type: :data)
    assert url.start_with?("data:image/png;base64,"), "Big image files should get a data URL by request! #{url.inspect}"
  end

  def test_large_file_outside_dirs
    url = fake_server.asset_url("#{__dir__}/../../docs/static/man-builds.png")
    assert url.start_with?("data:image/png;base64,"), "Large files outside dirs should still use data URLs"
  end

  def test_large_file_outside_dirs_with_exception
    assert_raises Scarpe::OperationNotAllowedError do
      url = fake_server.asset_url("#{__dir__}/../../docs/static/man-builds.png", url_type: :asset)
    end
  end
end
