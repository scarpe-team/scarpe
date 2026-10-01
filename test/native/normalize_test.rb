# frozen_string_literal: true

require_relative "helper"
require "socket"

class NormalizeTest < Minitest::Test
  include NativeTestHelpers
  include Shoes::Colors
  N = Scarpe::Native::Normalize
  PICTURE = "\x89PNG\r\n\x1A\nPNGDATA".b

  def rgba(*channels)
    { "rgba" => channels }
  end

  # Color arrays, as Lacci's color helpers build them

  def test_integer_arrays_pass_through_with_opaque_default
    assert_equal rgba(255, 0, 0, 255), N.color(red)
    assert_equal rgba(10, 20, 30, 255), N.color([10, 20, 30])
    assert_equal rgba(10, 20, 30, 40), N.color([10, 20, 30, 40])
  end

  def test_float_channels_are_fractions_of_255
    assert_equal rgba(128, 51, 26, 255), N.color(rgb(0.5, 0.2, 0.1))
    assert_equal rgba(128, 128, 128, 255), N.color(gray(0.5))
  end

  def test_each_channel_decides_int_or_float_on_its_own
    assert_equal rgba(255, 0, 0, 128), N.color(red(0.5)), "named color with a float alpha"
    assert_equal rgba(0, 102, 0, 255), N.color([0, 0.4, 0, 255]), "rgb(0, 0.4, 0) keeps its float green"
    assert_equal rgba(100, 100, 100, 255), N.color(gray(100))
  end

  def test_channels_are_clamped
    assert_equal rgba(255, 0, 255, 255), N.color([300, -5, 1.5])
  end

  def test_nofill_is_fully_transparent
    assert_equal rgba(0, 0, 0, 0), N.color([0, 0, 0, 0])
  end

  def test_arrays_that_are_not_colors_are_dropped
    assert_nil N.color([1, 2])
    assert_nil N.color(["#fff", "#000"])
  end

  # Color strings and symbols

  def test_short_hex_multiplies_by_17
    assert_equal rgba(170, 187, 204, 255), N.color("#abc")
    assert_equal rgba(221, 255, 170, 255), N.color("#DFA")
    assert_equal rgba(170, 187, 204, 221), N.color("#abcd")
  end

  def test_long_hex_with_and_without_alpha
    assert_equal rgba(170, 187, 204, 255), N.color("#aabbcc")
    assert_equal rgba(170, 187, 204, 128), N.color("#AABBCC80")
  end

  def test_named_colors_from_shoes_colors
    assert_equal rgba(255, 0, 0, 255), N.color("red")
    assert_equal rgba(0, 0, 0, 255), N.color(:black)
    assert_equal rgba(100, 149, 237, 255), N.color("CornflowerBlue")
    assert_equal rgba(211, 211, 211, 255), N.color("light gray"), "Shoes::COLORS only spells it lightgrey"
    assert_equal rgba(128, 128, 128, 255), N.color("gray"), "CSS gray, which Shoes::COLORS lacks"
  end

  def test_css_rgb_strings
    assert_equal rgba(255, 0, 0, 255), N.color("rgb(255,0,0)")
    assert_equal rgba(0, 0, 0, 128), N.color("rgba(0, 0, 0, 0.5)")
    assert_equal rgba(255, 200, 0, 255), N.color("rgba(255,200,0,255)")
    assert_equal rgba(255, 0, 0, 255), N.color("rgb(100%, 0%, 0%)")
  end

  def test_transparent_and_none
    assert_equal rgba(0, 0, 0, 0), N.color("transparent")
    assert_equal rgba(0, 0, 0, 0), N.color("none")
  end

  def test_unknown_color_strings_become_nil
    assert_nil N.color("notacolor")
    assert_nil N.color("#12345")
    assert_nil N.color(Object.new)
  end

  def test_nil_stays_nil
    assert_nil N.color(nil)
  end

  # Gradients

  def test_gradient_objects_keep_their_angle
    assert_equal({ "gradient" => [rgba(255, 0, 0, 255), rgba(0, 0, 255, 255)], "angle" => 0 }, N.color(gradient(red, blue)))
    assert_equal 90, N.color(gradient("#f00", "#00f", angle: 90))["angle"]
  end

  def test_color_ranges_run_top_to_bottom
    assert_equal({ "gradient" => [rgba(255, 255, 255, 255), rgba(0, 0, 0, 255)], "angle" => 0 }, N.color("#fff".."#000"))
    assert_equal [rgba(255, 0, 0, 255), rgba(0, 0, 255, 255)], N.color(red..blue)["gradient"]
  end

  # Images as paint, and image urls

  def test_image_paths_become_absolute_image_paint
    Dir.chdir(Dir.tmpdir) do
      assert_equal({ "image" => File.expand_path("bg.png") }, N.color("bg.png"))
      assert_equal File.expand_path("pics/cat.JPG"), N.prop("Image", "url", "pics/cat.JPG")
    end
  end

  def test_an_existing_file_without_an_image_extension_is_image_paint
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        File.write("texture", "not really an image")
        assert_equal({ "image" => File.join(Dir.pwd, "texture") }, N.color("texture"))
      end
    end
  end

  def test_blank_and_missing_image_urls_are_left_alone
    assert_equal "", N.prop("Image", "url", "")
    assert_nil N.prop("Image", "url", nil)
  end

  def test_video_urls_become_absolute_unless_remote
    Dir.chdir(Dir.tmpdir) { assert_equal File.expand_path("clip.mp4"), N.prop("Video", "url", "clip.mp4") }
    assert_equal "https://example.com/clip.mp4", N.prop("Video", "url", "https://example.com/clip.mp4")
  end

  def test_http_images_are_downloaded_once_into_the_cache
    with_image_server do |url, hits|
      with_cache_dir do |cache|
        path = N.prop("Image", "url", url)
        assert path.start_with?(cache), "#{path} should be in #{cache}"
        assert_equal PICTURE, File.binread(path)
        assert_equal({ "image" => path }, N.color(url))
        assert_equal 1, hits.size, "the second use reads the cache"
      end
    end
  end

  # The cache holds files fetched from anywhere and hands their paths to Rust, so nobody else
  # may put anything in it (review: a shared /tmp cache let another user plant links and files).

  def test_the_cache_is_a_private_directory_of_the_users_own_by_default
    Dir.mktmpdir do |home|
      with_env("SCARPE_NATIVE_CACHE" => nil, "HOME" => home, "XDG_CACHE_HOME" => nil, "LOCALAPPDATA" => home) do
        per_user = if Gem.win_platform? then %w[scarpe-native cache]
        elsif RUBY_PLATFORM.include?("darwin") then %w[Library Caches scarpe-native]
        else %w[.cache scarpe-native]
        end
        assert_equal File.join(home, *per_user), N.cache_dir, "never under the shared temp dir"
        # Windows keeps no Unix modes; %LOCALAPPDATA%'s access list makes it the user's own.
        assert_equal 0o700, File.stat(N.cache_dir).mode & 0o777 unless Gem.win_platform?
      end
    end
  end

  def test_a_cache_directory_others_could_write_to_is_made_private
    skip "Windows keeps no Unix modes to tighten" if Gem.win_platform?
    with_cache_dir do |cache|
      File.chmod(0o777, cache)
      N.cache_dir
      assert_equal 0o700, File.stat(cache).mode & 0o777
    end
  end

  def test_a_cache_directory_that_is_a_link_is_refused
    skip "Windows trusts %LOCALAPPDATA%'s access list, and links there need privileges" if Gem.win_platform?
    Dir.mktmpdir do |dir|
      Dir.mkdir(File.join(dir, "real"))
      File.symlink(File.join(dir, "real"), File.join(dir, "link"))
      with_image_server do |url, hits|
        with_env("SCARPE_NATIVE_CACHE" => File.join(dir, "link")) do
          assert_nil N.download(url)
          assert_empty hits, "nothing fetched into a directory we cannot vouch for"
          assert_empty Dir.children(File.join(dir, "real"))
        end
      end
    end
  end

  def test_a_link_planted_where_an_entry_goes_is_replaced_and_never_read
    with_victim do |victim, original|
      with_image_server do |url, hits|
        with_cache_dir do
          File.symlink(victim, N.cache_entry(url))
          path = N.download(url)
          refute File.symlink?(path), "the planted link is gone"
          assert_equal PICTURE, File.binread(path), "the entry is what the server sent"
          assert_equal 1, hits.size
          assert_equal original, File.binread(victim)
        end
      end
    end
  end

  def test_a_link_planted_where_the_download_is_written_is_never_written_through
    with_victim do |victim, original|
      with_image_server do |url, _hits|
        with_cache_dir do
          File.symlink(victim, "#{N.cache_entry(url)}.part")
          assert_equal PICTURE, File.binread(N.download(url))
          assert_equal original, File.binread(victim), "the victim's file is untouched"
        end
      end
    end
  end

  def test_an_entry_that_is_not_an_image_or_a_font_is_fetched_again
    with_image_server do |url, hits|
      with_cache_dir do
        File.write(N.cache_entry(url), "<html>502 Bad Gateway</html>")
        assert_equal PICTURE, File.binread(N.download(url))
        assert_equal 1, hits.size
      end
    end
  end

  def test_an_https_download_never_follows_a_redirect_to_http
    require "minitest/mock"
    require "net/http"
    moved = Net::HTTPFound.new("1.1", "302", "Found")
    moved["location"] = "http://127.0.0.1:9/cat.png"
    asked = []
    Net::HTTP.stub(:start, ->(host, *, **) { asked << host; moved }) do
      with_cache_dir { assert_nil N.download("https://example.com/cat-#{rand(1 << 30)}.png") }
    end
    assert_equal ["example.com"], asked, "the plain http location was never fetched"
  end

  def test_a_failed_download_is_nil
    with_cache_dir do
      server = TCPServer.new("127.0.0.1", 0)
      port = server.addr[1]
      server.close
      assert_nil N.prop("Image", "url", "http://127.0.0.1:#{port}/gone-#{rand(1 << 30)}.png")
    end
  end

  # Props and plain values

  def test_props_drop_the_linkable_id_and_procs
    wire = N.props("Link", { "shoes_linkable_id" => 9, "text_items" => ["hi"], "click" => proc {}, "has_block" => false })
    assert_equal({ "text_items" => ["hi"], "has_block" => true }, wire)
  end

  def test_props_keep_url_clicks
    assert_equal "http://shoesrb.com", N.props("Link", { "click" => "http://shoesrb.com" })["click"]
  end

  def test_owner_and_attach
    app = Shoes::Linkable.new(linkable_id: 7)
    assert_equal 7, N.prop("App", "owner", app)
    assert_equal "window", N.prop("Stack", "attach", Shoes::App)
    assert_equal "window", N.prop("Stack", "attach", Window)
    assert_equal 7, N.prop("Stack", "attach", app)
    assert_equal "center", N.prop("Stack", "attach", :center)
  end

  def test_draw_context_colors
    context = { "fill" => [255, 0, 0, 255], "stroke" => "#000", "strokewidth" => 2, "scale" => [1, 2], "rotate" => nil }
    assert_equal(
      { "fill" => rgba(255, 0, 0, 255), "stroke" => rgba(0, 0, 0, 255), "strokewidth" => 2, "scale" => [1, 2], "rotate" => nil },
      N.prop("Rect", "draw_context", context),
    )
  end

  def test_every_color_key_is_normalized
    %w[fill stroke color text_color background_color border_color undercolor strikecolor].each do |key|
      assert_equal rgba(255, 0, 0, 255), N.prop("Para", key, "red"), key
    end
  end

  def test_list_box_items_travel_as_strings
    assert_equal ["1", "two", "three"], N.prop("ListBox", "items", [1, :two, "three"])
    assert_equal "1", N.prop("ListBox", "chosen", 1)
    assert_nil N.prop("ListBox", "chosen", nil)
  end

  def test_plain_values
    assert_equal "para", N.value(:para)
    assert_equal ["Hello ", 5], N.value(["Hello ", 5])
    assert_equal [["move_to", 1, 2.5]], N.value([[:move_to, 1, 2.5]])
    assert_equal({ "a" => "b" }, N.value({ a: :b, c: proc {} }).slice("a"))
    refute N.value({ c: proc {} }).key?("c")
    assert_nil N.value(Float::NAN)
    assert_equal [1, 5], N.value(1..5)
    assert_equal 0.5, N.value(Rational(1, 2))
    assert_equal "Shoes::Para", N.value(Shoes::Para)
    assert_equal 12, N.value(Shoes::Linkable.new(linkable_id: 12))
  end

  def test_strings_become_valid_utf8
    bad = "caf\xE9".b
    assert N.value(bad).valid_encoding?
    assert_equal "café", N.value("café".encode("ISO-8859-1"))
    assert JSON.generate(N.props("Para", { "text_items" => [bad] }))
  end

  def test_whole_prop_hashes_are_json_safe
    props = {
      "fill" => gradient(red, blue), "stroke" => "#fff".."#000", "size" => :title, "features" => [:html],
      "owner" => Shoes::Linkable.new(linkable_id: 1), "click" => -> {}, "margin" => [1, 2, 3, 4], "width" => 0.5,
    }
    assert JSON.parse(JSON.generate(N.props("Para", props)))
  end

  private

  def with_cache_dir
    Dir.mktmpdir do |dir|
      previous = ENV["SCARPE_NATIVE_CACHE"]
      ENV["SCARPE_NATIVE_CACHE"] = dir
      yield dir
    ensure
      ENV["SCARPE_NATIVE_CACHE"] = previous
    end
  end

  # A file of someone's that a planted link points at, and what it held.
  def with_victim
    Dir.mktmpdir do |dir|
      victim = File.join(dir, "victim.png")
      original = "\x89PNG the victim's own picture".b
      File.binwrite(victim, original)
      yield victim, original
    end
  end

  def with_image_server
    server = TCPServer.new("127.0.0.1", 0)
    hits = []
    thread = Thread.new do
      loop do
        client = server.accept
        hits << client.gets
        while (header = client.gets) && header != "\r\n"; end
        client.write("HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: #{PICTURE.bytesize}\r\nConnection: close\r\n\r\n")
        client.write(PICTURE)
        client.close
      end
    rescue IOError
      nil
    end
    yield "http://127.0.0.1:#{server.addr[1]}/cat-#{rand(1 << 30)}.png", hits
  ensure
    server&.close
    thread&.kill
  end
end
