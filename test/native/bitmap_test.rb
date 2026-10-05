# frozen_string_literal: true

require_relative "helper"
require "base64"

class BitmapTest < Minitest::Test
  include NativeTestHelpers

  Service = Struct.new(:child) { include Scarpe::Native::Bitmaps }

  def service_with_reply(reply, calls = [])
    child = Object.new
    child.define_singleton_method(:request) { |op, **fields| calls << [op, fields]; reply }
    Service.new(child)
  end

  def test_upload_transmits_exact_bytes_without_mutating_the_input
    calls = []
    service = service_with_reply({ "value" => "memory:page-1" }, calls)
    pixels = [200, 100, 50, 128, 255, 255, 255, 0].pack("C*").freeze
    assert_equal "memory:page-1", service.cache_bitmap("memory:page-1", width: 2, height: 1, pixels: pixels)
    op, fields = calls.fetch(0)
    assert_equal :cache_bitmap, op
    assert_equal({ key: "memory:page-1", width: 2, height: 1, rgba: Base64.strict_encode64(pixels) }, fields)
    assert_equal [200, 100, 50, 128, 255, 255, 255, 0], pixels.bytes
  end

  def test_invalid_arguments_are_rejected_before_sending_or_encoding
    calls = []
    service = service_with_reply({ "value" => "memory:valid" }, calls)
    valid = { width: 1, height: 1, pixels: "\0\0\0\xFF".b }
    [nil, :key, "file.png", "memory:", "memory:a/b", "memory:a\\b", "memory:a\nb", "memory:é", "memory:#{'a' * 194}"].each do |key|
      assert_raises(ArgumentError) { service.cache_bitmap(key, **valid) }
      assert_raises(ArgumentError) { service.release_bitmap(key) }
      assert_raises(ArgumentError) { service.bitmap_size(key) }
    end
    [{ width: 0 }, { height: -1 }, { width: 1.0 }, { height: "1" }, { width: 16_385 },
      { width: 16_384, height: 16_384 }, { pixels: [0, 0, 0, 255] }, { pixels: "" }, { pixels: "short" }].each do |changes|
      assert_raises(ArgumentError) { service.cache_bitmap("memory:valid", **valid.merge(changes)) }
    end
    assert_empty calls
  end

  def test_renderer_errors_are_reported_and_unacknowledged_uploads_do_not_succeed
    service = service_with_reply({ "error" => "bitmap cache exceeds 128 MiB" })
    error = assert_raises(Scarpe::Native::BitmapError) do
      service.cache_bitmap("memory:page", width: 1, height: 1, pixels: "\0" * 4)
    end
    assert_match(/128 MiB/, error.message)
    assert_raises(Scarpe::Native::BitmapError) { service.release_bitmap("memory:page") }
    assert_raises(Scarpe::Native::BitmapError) { service.bitmap_size("memory:page") }
    service = service_with_reply({ "value" => nil })
    assert_raises(Scarpe::Native::BitmapError) { service.cache_bitmap("memory:page", width: 1, height: 1, pixels: "\0" * 4) }
    assert_raises(Scarpe::Native::BitmapError) { service.release_bitmap("memory:page") }
  end

  def test_release_is_idempotent_and_size_can_report_an_absent_key
    [true, false].each do |value|
      assert_equal value, service_with_reply({ "value" => value }).release_bitmap("memory:page")
    end
    assert_equal [2, 3], service_with_reply({ "value" => [2, 3] }).bitmap_size("memory:page")
    assert_nil service_with_reply({ "value" => nil }).bitmap_size("memory:page")
    assert_raises(Scarpe::Native::BitmapError) { service_with_reply({ "value" => [0, 3] }).bitmap_size("memory:page") }
  end

  def test_memory_sources_survive_normalization_in_images_icons_and_patterns
    n = Scarpe::Native::Normalize
    assert_equal "memory:page", n.props("Image", url: "memory:page")["url"]
    assert_equal "memory:page", n.props("Button", icon: "memory:page")["icon"]
    assert_equal({ "image" => "memory:page" }, n.props("Rect", fill: "memory:page")["fill"])
    assert_equal({ "image" => "memory:page" }, n.props("Rect", draw_context: { stroke: "memory:page" }).dig("draw_context", "stroke"))
  end

  def test_ruby_images_upload_replace_measure_click_and_release_without_files
    skip_without_real_binary
    run = run_real(<<~'APP', test_code: <<~'TEST', env: { "SCARPE_NATIVE_DAMAGE" => "check" })
      $bitmaps = Shoes::DisplayService.display_service
      $key = $bitmaps.cache_bitmap("memory:page", width: 2, height: 3, pixels: [255, 0, 0, 255].pack("C*") * 6)
      $before_app = imagesize($key)
      $clicks = 0
      Shoes.app(width: 200, height: 120) do
        @page = image($key, width: 40, height: 60) { $clicks += 1 }
        @natural = image $key, left: 80, top: 0
      end
    APP
      assert_equal [2, 3], $before_app
      assert_equal [2, 3], image("@page").size
      assert_equal [2, 3], [image("@page").full_width, image("@page").full_height]
      assert_equal [2, 3], [layout_of(image("@natural")).w, layout_of(image("@natural")).h]
      assert_equal [255, 0, 0, 255], pixel_at(20, 20)
      click_on image("@page")
      assert_equal 1, $clicks, "string image sources keep their click blocks"
      $bitmaps.cache_bitmap($key, width: 4, height: 2, pixels: [0, 128, 0, 255].pack("C*") * 8)
      assert_equal [4, 2], imagesize($key)
      assert_equal [4, 2], image("@page").size
      assert_equal [4, 2], [layout_of(image("@natural")).w, layout_of(image("@natural")).h]
      assert_equal [0, 128, 0, 255], pixel_at(20, 20)
      assert $bitmaps.release_bitmap($key)
      refute $bitmaps.release_bitmap($key)
      assert_nil imagesize($key)
      assert_equal [nil, nil], image("@page").size
      refute_equal [0, 128, 0, 255], pixel_at(20, 20)
      $bitmaps.cache_bitmap($key, width: 1, height: 1, pixels: [0, 0, 255, 255].pack("C*"))
      assert_equal [0, 0, 255, 255], pixel_at(20, 20)
    TEST
    assert_spec_passed(run)
    refute_match(/damage check:/, run.stderr)
  end

  def test_a_bitmap_larger_than_the_pipe_buffer_crosses_the_real_protocol
    skip_without_real_binary
    run = run_real(<<~'APP', test_code: <<~'TEST')
      $bitmaps = Shoes::DisplayService.display_service
      key = $bitmaps.cache_bitmap("memory:large", width: 400, height: 300, pixels: [10, 20, 30, 255].pack("C*") * 120_000)
      Shoes.app(width: 100, height: 80) { @page = image key, width: 80, height: 60 }
    APP
      assert_equal [400, 300], image("@page").size
      assert_equal [10, 20, 30, 255], pixel_at(40, 30)
      assert $bitmaps.release_bitmap("memory:large")
    TEST
    assert_spec_passed(run)
  end
end
