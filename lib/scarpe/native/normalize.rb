# frozen_string_literal: true

require "fileutils"

# Ruby value -> wire value, in one place (DESIGN 5.3). Everything that crosses to Rust goes
# through here, so Rust only ever sees JSON data: colors as {"rgba"}, {"gradient"} or {"image"},
# absolute paths, ids instead of objects, and no Procs.
module Scarpe::Native::Normalize
  extend self

  COLOR_KEYS = %w[fill stroke color text_color background_color border_color undercolor strikecolor].freeze
  IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .gif .bmp .webp .svg .tif .tiff .ico].freeze
  TRANSPARENT = { "rgba" => [0, 0, 0, 0] }.freeze

  # The manual: gradients run top to bottom unless given an angle, and a Range carries none.
  RANGE_ANGLE = 0

  # CSS names Shoes::COLORS lacks.
  EXTRA_COLORS = { gray: [128, 128, 128], grey: [128, 128, 128] }.freeze

  # Stands in for a value that cannot cross the process boundary (a Proc); containers skip it.
  DROP = Object.new.freeze

  # How the image and font files Rust reads begin: PNG, JPEG, GIF, BMP, WebP, TIFF (both byte
  # orders), ICO, TrueType, OpenType, a font collection, WOFF and WOFF2.
  MEDIA_SIGNATURES = [
    "\x89PNG", "\xFF\xD8\xFF", "GIF8", "BM", "RIFF", "II*\x00", "MM\x00*", "\x00\x00\x01\x00",
    "\x00\x01\x00\x00", "OTTO", "true", "ttcf", "wOFF", "wOF2",
  ].map(&:b).freeze

  def props(kind, hash)
    dropped_click = false
    out = hash.each_with_object({}) do |(key, value), wire|
      key = key.to_s
      next if key == "shoes_linkable_id"

      converted = prop(kind, key, value)
      if converted.equal?(DROP)
        dropped_click ||= key == "click"
      else
        wire[key] = converted
      end
    end
    out["has_block"] = true if dropped_click
    out
  end

  def prop(kind, key, value)
    case key
    when *COLOR_KEYS then color(value)
    when "draw_context" then draw_context(value)
    when "url" then kind == "Image" ? image_path(value) : local_path(value)
    when "icon" then image_path(value)
    when "attach" then attach(value)
    when "items" then value && Array(value).map(&:to_s)
    when "chosen" then value&.to_s
    else value(value)
    end
  end

  def value(value)
    case value
    when nil, true, false, Integer then value
    when Float then value.finite? ? value : nil
    when String then utf8(value)
    when Symbol then value.to_s
    when Array then value.map { |item| value(item) }.reject { |item| item.equal?(DROP) }
    when Hash then value.to_h { |k, v| [k.to_s, value(v)] }.reject { |_k, v| v.equal?(DROP) }
    when Range then [value(value.begin), value(value.end)]
    when Proc, Method then DROP
    when Shoes::Colors::Gradient then color(value)
    when Shoes::Linkable then value.linkable_id
    when Numeric then value.to_f
    when Module then value.name
    else utf8(value.to_s)
    end
  end

  # Colors

  def color(value)
    case value
    when nil then nil
    when Shoes::Colors::Gradient then gradient(value.color1, value.color2, value.angle)
    when Range then gradient(value.begin, value.end, RANGE_ANGLE)
    when Array then rgba_array(value)
    when Symbol then named_color(value.to_s)
    when String then color_string(value)
    else unknown_color(value)
    end
  end

  def gradient(from, to, angle)
    stops = [color(from), color(to)]
    return nil if stops.compact.empty?

    { "gradient" => stops, "angle" => value(angle) || RANGE_ANGLE }
  end

  # Per component: a Float is a fraction of 255, an Integer is already 0..255 (Shoes 3's NUM2RGBINT).
  def rgba_array(channels)
    return unknown_color(channels) unless [3, 4].include?(channels.size) && channels.all?(Numeric)

    r, g, b, a = channels.map { |c| channel(c) }
    { "rgba" => [r, g, b, a || 255] }
  end

  def channel(value)
    value = value.to_f unless value.is_a?(Integer)
    value = (value * 255).round if value.is_a?(Float)
    value.clamp(0, 255)
  end

  def color_string(string)
    text = string.strip
    case text
    when /\A#\h+\z/ then hex_color(text) || unknown_color(string)
    when /\Argba?\(([^)]*)\)\z/i then css_rgb(Regexp.last_match(1)) || unknown_color(string)
    when /\A(transparent|none)\z/i then TRANSPARENT
    when %r{\Ahttps?://}i then image_paint(text)
    else named_color(text) || image_paint(text) || unknown_color(string)
    end
  end

  def hex_color(hex)
    digits = hex.delete_prefix("#")
    case digits.size
    when 3, 4 then { "rgba" => rgba_with_opaque_default(digits.chars.map { |d| d.to_i(16) * 17 }) }
    when 6, 8 then { "rgba" => rgba_with_opaque_default(digits.scan(/\h\h/).map { |d| d.to_i(16) }) }
    end
  end

  # CSS rgb()/rgba(): channels 0..255 or percentages; alpha is a fraction when <= 1, else 0..255.
  def css_rgb(body)
    parts = body.split(/[\s,\/]+/).reject(&:empty?)
    return nil unless [3, 4].include?(parts.size)

    rgb = parts.first(3).map do |part|
      part.end_with?("%") ? (part.to_f * 2.55).round.clamp(0, 255) : part.to_f.round.clamp(0, 255)
    end
    alpha = parts[3] && css_alpha(parts[3])
    { "rgba" => rgb + [alpha || 255] }
  end

  def css_alpha(part)
    number = part.end_with?("%") ? part.to_f / 100 : part.to_f
    (number <= 1.0 ? number * 255 : number).round.clamp(0, 255)
  end

  def named_color(name)
    key = name.downcase.delete(" _")
    rgb = [key, key.gsub("grey", "gray"), key.gsub("gray", "grey")].lazy.map do |candidate|
      Shoes::COLORS[candidate.to_sym] || EXTRA_COLORS[candidate.to_sym]
    end.find(&:itself)
    rgb && { "rgba" => rgb + [255] }
  end

  def rgba_with_opaque_default(channels)
    channels.size == 3 ? channels + [255] : channels
  end

  # A color string that is really an image to paint with ("bg.png", an http URL).
  def image_paint(text)
    return nil unless text.match?(%r{\Ahttps?://}i) || image_like?(text)

    path = image_path(text)
    path && { "image" => path }
  end

  def image_like?(text)
    IMAGE_EXTENSIONS.include?(File.extname(text).downcase) || File.file?(File.expand_path(text))
  end

  def unknown_color(value)
    @unknown_colors ||= Set.new
    log.warn("Don't know how to draw the color #{value.inspect}; leaving it unset") if @unknown_colors.add?(value.inspect)
    nil
  end

  # Paths and objects

  def draw_context(context)
    return nil unless context.is_a?(Hash)

    context.each_with_object({}) do |(key, v), out|
      key = key.to_s
      out[key] = %w[fill stroke].include?(key) ? color(v) : value(v)
    end
  end

  def attach(target)
    case target
    when nil then nil
    when Class then target <= Shoes::App ? "window" : target.name
    when Shoes::Linkable then target.linkable_id
    else target.to_s
    end
  end

  # Image files: local paths made absolute, http(s) downloaded once. "" is image(w, h)'s blank canvas.
  def image_path(url)
    return url if url.nil? || url == ""

    url = url.to_s
    url.match?(%r{\Ahttps?://}i) ? download(url) : File.expand_path(url)
  end

  def local_path(url)
    return url if url.nil? || url == "" || url.to_s.match?(%r{\A[a-z][a-z0-9+.-]*://}i)

    File.expand_path(url.to_s)
  end

  alias_method :font_path, :image_path

  # net/http and friends cost ~45 ms at startup (native/PERF.md), so only a download loads them.
  def download(url)
    @downloads ||= {}
    return @downloads[url] if @downloads.key?(url)

    path = cache_entry(url)
    fetch(url, path) unless cached?(path)
    @downloads[url] = path
  rescue StandardError => e
    log.warn("Could not download #{url}: #{e.class}: #{e.message}")
    @downloads[url] = nil
  end

  def cache_entry(url)
    require "digest"
    require "uri"
    File.join(cache_dir, Digest::SHA256.hexdigest(url)[0, 32] + File.extname(URI(url).path.to_s))
  end

  # Rust reads whatever path the cache hands it, so the cache is the user's own: never the
  # shared temp dir, where another user could plant a link or a file first.
  def cache_dir
    dir = ENV["SCARPE_NATIVE_CACHE"].to_s
    dir = per_user_cache_dir if dir.empty?
    FileUtils.mkdir_p(dir, mode: 0o700)
    private_dir(dir)
  end

  def utf8(string)
    return string if string.valid_encoding? && (string.encoding == Encoding::UTF_8 || string.ascii_only?)

    if string.encoding == Encoding::BINARY
      string.dup.force_encoding(Encoding::UTF_8).scrub
    else
      string.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end
  end

  private

  def per_user_cache_dir
    if Gem.win_platform?
      File.join(ENV.fetch("LOCALAPPDATA", Dir.home), "scarpe-native", "cache")
    elsif RUBY_PLATFORM.include?("darwin")
      File.join(Dir.home, "Library", "Caches", "scarpe-native")
    else
      xdg = ENV["XDG_CACHE_HOME"].to_s
      File.join(xdg.empty? ? File.join(Dir.home, ".cache") : xdg, "scarpe-native")
    end
  end

  # A directory of our own, not a link, that nobody else may write to.
  def private_dir(dir)
    return dir if Gem.win_platform? # %LOCALAPPDATA% belongs to the user by its access list

    stat = File.lstat(dir)
    raise "the cache #{dir} is a link" if stat.symlink?
    raise "the cache #{dir} is not a directory" unless stat.directory?
    raise "the cache #{dir} belongs to someone else" unless stat.owned?

    File.chmod(0o700, dir) unless (stat.mode & 0o077).zero?
    dir
  end

  # An entry counts only as a plain file of ours that starts like an image or a font: never a
  # link, a pipe, a stranger's file or a saved error page.
  def cached?(path)
    stat = File.lstat(path)
    stat.file? && stat.owned? && media?(File.binread(path, 16))
  rescue SystemCallError
    false
  end

  def media?(head)
    MEDIA_SIGNATURES.any? { |signature| head.start_with?(signature) }
  end

  def fetch(url, path, redirects_left: 5)
    require "net/http"
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 10) do |http|
      http.request(Net::HTTP::Get.new(uri))
    end

    case response
    when Net::HTTPRedirection
      raise "too many redirects" if redirects_left.zero?

      target = URI.join(url, response["location"])
      raise "refusing the redirect from https to #{target}" if uri.scheme == "https" && target.scheme != "https"

      fetch(target.to_s, path, redirects_left: redirects_left - 1)
    when Net::HTTPSuccess
      write_entry(path, response.body)
    else
      raise "HTTP #{response.code}"
    end
  end

  # Into a new file with a name nobody could guess (created exclusively, 0600), then renamed over
  # the entry: a link planted at either name is replaced, never written through.
  def write_entry(path, body)
    require "tempfile"
    part = Tempfile.create(["#{File.basename(path)}.", ".part"], File.dirname(path))
    part.binmode
    part.write(body)
    part.close
    File.rename(part.path, path)
  ensure
    File.unlink(part.path) if part && File.exist?(part.path)
  end

  def log
    @log ||= Shoes::Log.logger("Scarpe::Native::Normalize")
  end
end
