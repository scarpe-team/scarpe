# frozen_string_literal: true

require "fileutils"
require "open-uri"
require "json"

module Scarpe
  # Package a Shoes/Scarpe application into a standalone macOS .app bundle.
  #
  # Usage:
  #   Scarpe::Package.new("myapp.rb").build!
  #   Scarpe::Package.new("myapp.rb", name: "MyApp", icon: "icon.icns").build!
  #
  # The packaged app bundles Traveling Ruby (a self-contained Ruby interpreter)
  # along with all Scarpe gems and the user's application. The resulting .app
  # requires no Ruby installation to run.
  class Package
    TRAVELING_RUBY_RELEASE = "20251122"
    TRAVELING_RUBY_VERSION = "3.4.7"
    RUBY_ABI = "3.4.0"

    # GitHub base URL for Traveling Ruby releases
    RELEASE_BASE = "https://github.com/trubygems/traveling-ruby/releases/download/rel-#{TRAVELING_RUBY_RELEASE}"

    # Architecture mappings
    ARCH_MAP = {
      "x86_64" => "x86_64",
      "arm64" => "arm64",
      "aarch64" => "arm64",
    }.freeze

    # Supported target operating systems
    TARGET_OS_MAP = {
      "macos" => "macos",
      "darwin" => "macos",
      "linux" => "linux",
      "linux-musl" => "linux-musl",  # Alpine/Docker
      "windows" => "windows",
      "mingw" => "windows",
      "mswin" => "windows",
    }.freeze

    # Platform directory names vary between extensions and stdlib in Traveling Ruby:
    #   Extensions: x86_64-darwin-22 (with hyphen)
    #   Stdlib:     x86_64-darwin22  (no hyphen)
    # macOS platforms
    EXT_PLATFORM = { "x86_64" => "x86_64-darwin-22", "arm64" => "arm64-darwin-22" }.freeze
    RUBY_PLATFORM_DIR = { "x86_64" => "x86_64-darwin22", "arm64" => "arm64-darwin22" }.freeze

    # Linux platforms (glibc)
    LINUX_EXT_PLATFORM = { "x86_64" => "x86_64-linux", "arm64" => "aarch64-linux" }.freeze
    LINUX_RUBY_PLATFORM_DIR = { "x86_64" => "x86_64-linux", "arm64" => "aarch64-linux" }.freeze

    # Linux musl platforms (Alpine)
    LINUX_MUSL_EXT_PLATFORM = { "x86_64" => "x86_64-linux-musl", "arm64" => "aarch64-linux-musl" }.freeze
    LINUX_MUSL_RUBY_PLATFORM_DIR = { "x86_64" => "x86_64-linux-musl", "arm64" => "aarch64-linux-musl" }.freeze

    # Windows platforms
    # Note: Traveling Ruby uses "x64-mingw-ucrt" for Ruby 3.2+ gems
    WINDOWS_EXT_PLATFORM = { "x86_64" => "x64-mingw-ucrt", "arm64" => "arm64-mingw-ucrt" }.freeze
    WINDOWS_RUBY_PLATFORM_DIR = { "x86_64" => "x64-mingw-ucrt", "arm64" => "arm64-mingw-ucrt" }.freeze

    # Native extension file extensions by platform
    LINUX_EXT_SUFFIX = ".so"
    MACOS_EXT_SUFFIX = ".bundle"
    WINDOWS_EXT_SUFFIX = ".dll"

    # Gems required for the Scarpe runtime, copied from the full Traveling Ruby tarball.
    # Format: [gem_name, version, platform_suffix_or_nil]
    # Platform gems (nokogiri, sqlite3) bundle their own native extensions.
    # Non-platform gems with native extensions (ffi, racc, syslog) need the
    # extensions directory from the Traveling Ruby build.
    REQUIRED_GEMS = [
      ["scarpe",            nil, nil],
      ["lacci",             nil, nil],
      ["scarpe-components", nil, nil],
      ["webview_ruby",    "0.1.2", nil],
      ["ffi",             "1.17.2", nil],
      ["ffi-compiler",    "1.3.2", nil],
      ["webrick",           nil, nil],
      ["fastimage",       "2.2.7", nil],
      ["logging",         "2.3.1", nil],
      ["little-plugger",  "1.1.4", nil],
      ["multi_json",        nil, nil],
      ["base64",            nil, nil],
      ["minitest",          nil, nil],
      ["rake",              nil, nil],
      ["racc",              nil, nil],
      ["syslog",            nil, nil],
    ].freeze

    # Platform-specific gems (these have native extensions bundled in the gem itself)
    # We pick the right platform variant based on target architecture.
    PLATFORM_GEMS = {
      "x86_64" => [
        ["nokogiri", "1.15.7", "x86_64-darwin"],
        ["sqlite3",  "1.6.9",  "x86_64-darwin"],
      ],
      "arm64" => [
        ["nokogiri", "1.18.10", "arm64-darwin"],
        ["sqlite3",  "2.8.0",   "arm64-darwin"],
      ],
    }.freeze

    # Native extensions that need the extensions/ directory from Traveling Ruby
    NATIVE_EXTENSION_GEMS = %w[ffi racc syslog webview_ruby].freeze

    # Scarpe source directories (relative to scarpe repo root)
    SCARPE_DEV_GEMS = {
      "scarpe" => { lib: "lib", spec_name: "scarpe" },
      "lacci" => { lib: "lacci/lib", spec_name: "lacci" },
      "scarpe-components" => { lib: "scarpe-components/lib", spec_name: "scarpe-components" },
    }.freeze

    # Gems that are truly optional — only loaded when specific Shoes features are used.
    # nokogiri: only for Shoes#download XML parsing
    # sqlite3: not used by Scarpe at all (phantom gemspec dependency)
    # fastimage: only for Image widget auto-sizing
    # rake: build tool, not runtime
    # minitest: testing framework, not runtime
    OPTIONAL_GEMS = %w[nokogiri sqlite3 fastimage rake].freeze  # minitest needed by scarpe/shoes_spec.rb

    # Stdlib modules safe to strip in minimal mode (not loaded by Scarpe runtime)
    # These are all development/build/network tools not needed for GUI apps.
    MINIMAL_STRIP_STDLIB = %w[
      openssl net fiddle ripper
      mkmf irb rdoc racc/cparse
      rinda drb nkf coverage getoptlong
    ].freeze

    # Additional large files safe to remove in ultra-minimal mode
    MINIMAL_STRIP_FILES = %w[
      mkmf.rb rdoc.rb irb.rb tracer.rb debug.rb
      benchmark.rb profile.rb profiler.rb
      getoptlong.rb coverage.rb
    ].freeze

    def initialize(app_file, name: nil, icon: nil, arch: nil, output_dir: nil, verbose: false, dev: false, sign: false, dmg: false, universal: false, minimal: false, target_os: nil, skip_webview_check: false)
      @app_file = File.expand_path(app_file)
      raise "App file not found: #{@app_file}" unless File.exist?(@app_file)
      raise "App file must be a .rb file: #{@app_file}" unless @app_file.end_with?(".rb")

      @name = sanitize_name(name || File.basename(app_file, ".rb"))
      @icon = icon ? File.expand_path(icon) : nil
      @arch = ARCH_MAP[arch || detect_arch] || raise("Unsupported architecture: #{arch}")
      @target_os = TARGET_OS_MAP[target_os || detect_os] || raise("Unsupported OS: #{target_os}")
      @output_dir = output_dir ? File.expand_path(output_dir) : Dir.pwd
      @verbose = verbose
      @dev = dev
      @sign = sign
      @dmg = dmg
      @universal = universal
      @minimal = minimal
      @skip_webview_check = skip_webview_check

      # Validate options
      if @target_os != "macos" && (@sign || @dmg || @universal)
        warn "⚠️  --sign, --dmg, and --universal are macOS-only options (ignored for #{@target_os})"
        @sign = false
        @dmg = false
        @universal = false
      end

      # Windows-specific validation
      if @target_os == "windows" && @arch == "arm64" && TRAVELING_RUBY_VERSION < "3.4.7"
        raise "Windows arm64 requires Ruby 3.4.7+ (current: #{TRAVELING_RUBY_VERSION})"
      end

      @cache_dir = File.join(Dir.home, ".scarpe", "packager-cache")
      @bundle_id = "com.scarpe.#{@name.downcase.gsub(/[^a-z0-9]/, "")}"

      if @dev
        @scarpe_root = find_scarpe_root
        raise "Cannot find Scarpe source root (expected lib/scarpe/)" unless @scarpe_root
      end
    end

    def build!
      log "🔨 Scarpe Packager"
      log "   App:    #{@app_file}"
      log "   Name:   #{@name}"
      log "   Arch:   #{@arch}"
      log "   Target: #{@target_os}"
      log "   Mode:   #{@minimal ? "minimal" : "full"}"
      log "   Output: #{output_path}"
      log ""

      case @target_os
      when "macos"
        build_macos!
      when "linux", "linux-musl"
        build_linux!
      when "windows"
        build_windows!
      else
        raise "Unsupported target OS: #{@target_os}"
      end
    end

    def build_macos!
      ensure_runtime_cached
      create_bundle_structure
      copy_ruby_runtime
      copy_gems
      copy_native_extensions
      copy_webview_extension
      copy_user_app
      write_boot_script
      write_launcher
      write_info_plist
      copy_icon if @icon
      strip_unnecessary_files
      sign_bundle if @sign
      result = create_dmg if @dmg

      size = `du -sh "#{app_path}" 2>/dev/null`.strip.split("\t").first || "unknown"
      log ""
      log "✅ Created #{File.basename(app_path)} (#{size})"

      if result && @dmg
        dmg_size = `du -sh "#{result}" 2>/dev/null`.strip.split("\t").first || "unknown"
        log "✅ Created #{File.basename(result)} (#{dmg_size})"
        log ""
        log "   To install: open #{result}"
      else
        log ""
        log "   To run:  open #{app_path}"
        log "   Or:      #{app_path}/Contents/MacOS/scarpe-launcher"
      end

      unless @sign
        log ""
        log "   ⚠️  Unsigned app — right-click → Open to bypass Gatekeeper."
        log "   Tip: use --sign for ad-hoc code signing (no Apple Developer account needed)."
      end

      @dmg ? result : app_path
    end

    def build_linux!
      ensure_runtime_cached
      create_appimage_structure
      copy_ruby_runtime_linux
      copy_gems_linux
      copy_native_extensions_linux
      copy_webview_extension_linux
      copy_user_app_linux
      write_boot_script_linux
      write_apprun_script
      write_desktop_file
      copy_icon_linux if @icon
      strip_unnecessary_files_linux

      appimage_path = create_appimage
      size = `du -sh "#{appimage_path}" 2>/dev/null`.strip.split("\t").first || "unknown"
      log ""
      log "✅ Created #{File.basename(appimage_path)} (#{size})"
      log ""
      log "   To run:  chmod +x #{appimage_path} && ./#{File.basename(appimage_path)}"
      log ""
      log "   ⚠️  Requires WebKitGTK installed on the target system:"
      log "      Ubuntu/Debian: sudo apt install libwebkit2gtk-4.1-0"
      log "      Fedora:        sudo dnf install webkit2gtk4.1"
      log "      Arch:          sudo pacman -S webkit2gtk"

      appimage_path
    end

    def build_windows!
      ensure_runtime_cached
      create_windows_structure
      copy_ruby_runtime_windows
      copy_gems_windows
      copy_native_extensions_windows
      copy_webview_extension_windows
      copy_user_app_windows
      write_boot_script_windows
      write_windows_launcher
      copy_icon_windows if @icon
      strip_unnecessary_files_windows

      result = create_windows_zip

      log ""
      log "✅ Created #{File.basename(windows_output_path)}/"
      log ""
      log "   To run: Double-click #{@name}.bat"
      log "   Or:     #{@name}\\ruby\\bin\\ruby.exe #{@name}\\app\\boot.rb"
      log ""
      log "   ⚠️  Requires WebView2 Runtime installed on the target system:"
      log "      Windows 11: Pre-installed"
      log "      Windows 10: Download from https://developer.microsoft.com/en-us/microsoft-edge/webview2/"
      log ""
      log "   📦 Distribution: Share the #{@name} folder or #{@name}.zip"

      result
    end

    def output_path
      case @target_os
      when "macos"
        app_path
      when "linux", "linux-musl"
        appimage_path
      when "windows"
        windows_output_path
      else
        raise "Unknown target OS: #{@target_os}"
      end
    end

    def windows_output_path
      File.join(@output_dir, @name)
    end

    def windows_exe_path
      File.join(windows_output_path, "#{@name}.bat")
    end

    def app_path
      File.join(@output_dir, "#{@name}.app")
    end

    def appimage_path
      File.join(@output_dir, "#{@name}-#{@arch}.AppImage")
    end

    def appdir_path
      File.join(@output_dir, "#{@name}.AppDir")
    end

    private

    def log(msg)
      puts msg
    end

    def vlog(msg)
      puts "  [debug] #{msg}" if @verbose
    end

    def dir_size(path)
      return 0 unless Dir.exist?(path)
      Dir.glob(File.join(path, "**/*")).sum { |f| File.file?(f) ? File.size(f) : 0 }
    end

    def find_scarpe_root
      # Walk up from this file to find the Scarpe repo root
      dir = File.expand_path("../../..", __FILE__)
      return dir if File.exist?(File.join(dir, "lib/scarpe")) && File.exist?(File.join(dir, "lacci/lib"))

      # Try common locations
      candidates = [
        File.expand_path("~/Progrumms/scarpe"),
        File.expand_path("../scarpe", Dir.pwd),
      ]
      candidates.find { |d| File.exist?(File.join(d, "lib/scarpe")) && File.exist?(File.join(d, "lacci/lib")) }
    end

    def sanitize_name(name)
      clean = name.gsub(/[^a-zA-Z0-9_\- ]/, "").strip
      clean = "ScarpeApp" if clean.empty?
      # Capitalize words for display name
      clean.split(/[\s_-]+/).map(&:capitalize).join("")
    end

    def detect_arch
      `uname -m`.strip
    end

    def detect_os
      case RbConfig::CONFIG["host_os"]
      when /darwin/i
        "macos"
      when /linux/i
        # Check if musl-based (Alpine)
        if `ldd --version 2>&1`.include?("musl")
          "linux-musl"
        else
          "linux"
        end
      when /mswin|mingw|cygwin/i
        "windows"  # Not yet supported
      else
        "unknown"
      end
    end

    def platform_string
      case @target_os
      when "macos"
        "macos-#{@arch}"
      when "linux"
        "linux-#{@arch}"
      when "linux-musl"
        "linux-musl-#{@arch}"
      when "windows"
        "windows-#{@arch}"
      else
        raise "Unknown target OS: #{@target_os}"
      end
    end

    def ext_platform_dir
      case @target_os
      when "macos"
        EXT_PLATFORM[@arch]
      when "linux"
        LINUX_EXT_PLATFORM[@arch]
      when "linux-musl"
        LINUX_MUSL_EXT_PLATFORM[@arch]
      when "windows"
        WINDOWS_EXT_PLATFORM[@arch]
      else
        raise "Unknown target OS: #{@target_os}"
      end
    end

    def ruby_platform_dir
      case @target_os
      when "macos"
        RUBY_PLATFORM_DIR[@arch]
      when "linux"
        LINUX_RUBY_PLATFORM_DIR[@arch]
      when "linux-musl"
        LINUX_MUSL_RUBY_PLATFORM_DIR[@arch]
      when "windows"
        WINDOWS_RUBY_PLATFORM_DIR[@arch]
      else
        raise "Unknown target OS: #{@target_os}"
      end
    end

    def native_ext_suffix
      case @target_os
      when "macos"
        MACOS_EXT_SUFFIX
      when "windows"
        WINDOWS_EXT_SUFFIX
      else
        LINUX_EXT_SUFFIX
      end
    end

    def runtime_tarball_url
      "#{RELEASE_BASE}/traveling-ruby-#{TRAVELING_RUBY_RELEASE}-#{TRAVELING_RUBY_VERSION}-#{platform_string}-full.tar.gz"
    end

    def runtime_cache_path
      File.join(@cache_dir, "traveling-ruby-#{TRAVELING_RUBY_VERSION}-#{platform_string}-full")
    end

    def tarball_cache_path
      File.join(@cache_dir, "traveling-ruby-#{TRAVELING_RUBY_VERSION}-#{platform_string}-full.tar.gz")
    end

    # --- Cache Management ---

    def ensure_runtime_cached
      FileUtils.mkdir_p(@cache_dir)

      if Dir.exist?(runtime_cache_path) && Dir.children(runtime_cache_path).any?
        log "✅ Using cached Traveling Ruby #{TRAVELING_RUBY_VERSION} (#{@arch})"
        return
      end

      download_runtime
      extract_runtime
    end

    def download_runtime
      return if File.exist?(tarball_cache_path)

      log "📦 Downloading Traveling Ruby #{TRAVELING_RUBY_VERSION} (#{@arch})..."
      log "   URL: #{runtime_tarball_url}"

      # Use curl for reliable large downloads with redirect following
      system("curl", "-L", "--progress-bar", "-o", tarball_cache_path, runtime_tarball_url)
      raise "Download failed!" unless $?.success? && File.exist?(tarball_cache_path)

      log "   Downloaded #{(File.size(tarball_cache_path) / 1024.0 / 1024.0).round(1)}MB"
    end

    def extract_runtime
      log "📦 Extracting runtime..."
      FileUtils.mkdir_p(runtime_cache_path)
      system("tar", "xzf", tarball_cache_path, "-C", runtime_cache_path)
      raise "Extraction failed!" unless $?.success?
      log "   Extracted to #{runtime_cache_path}"
    end

    # --- Bundle Creation ---

    def create_bundle_structure
      log "📁 Creating .app bundle..."
      FileUtils.rm_rf(app_path)
      %w[Contents/MacOS Contents/Resources/app Contents/Resources/runtime/ruby Contents/Resources/runtime/gems/gems Contents/Resources/runtime/gems/specifications Contents/Resources/runtime/gems/extensions].each do |dir|
        FileUtils.mkdir_p(File.join(app_path, dir))
      end
    end

    def copy_ruby_runtime
      log "💎 Copying Ruby runtime..."
      src = runtime_cache_path
      dst_ruby = File.join(app_path, "Contents/Resources/runtime/ruby")

      # Copy binary directories
      FileUtils.cp_r(File.join(src, "bin"), File.join(dst_ruby, "bin"))
      FileUtils.cp_r(File.join(src, "bin.real"), File.join(dst_ruby, "bin.real"))

      # Copy lib (dylibs, certs, stdlib) but NOT gems
      dst_lib = File.join(dst_ruby, "lib")
      FileUtils.mkdir_p(dst_lib)

      # Dylibs and certs
      Dir.glob(File.join(src, "lib", "*.dylib")).each { |f| FileUtils.cp(f, dst_lib) }
      Dir.glob(File.join(src, "lib", "*.crt")).each { |f| FileUtils.cp(f, dst_lib) }

      # Ruby stdlib (not gems)
      dst_ruby_lib = File.join(dst_ruby, "lib/ruby")
      FileUtils.mkdir_p(dst_ruby_lib)
      FileUtils.cp_r(File.join(src, "lib/ruby/#{RUBY_ABI}"), File.join(dst_ruby_lib, RUBY_ABI))

      %w[site_ruby vendor_ruby].each do |dir|
        src_dir = File.join(src, "lib/ruby", dir)
        FileUtils.cp_r(src_dir, File.join(dst_ruby_lib, dir)) if Dir.exist?(src_dir)
      end

      # Create empty gems directory for RubyGems to find
      FileUtils.mkdir_p(File.join(dst_ruby, "lib/ruby/gems/#{RUBY_ABI}/specifications"))

      vlog "Ruby runtime copied"
    end

    def copy_gems
      log "💎 Copying Scarpe gems..."
      src_gems = File.join(runtime_cache_path, "lib/ruby/gems/#{RUBY_ABI}")
      dst_gems = File.join(app_path, "Contents/Resources/runtime/gems")

      all_gems = REQUIRED_GEMS + (PLATFORM_GEMS[@arch] || [])

      all_gems.each do |gem_name, version, platform|
        gem_dir_name = find_gem_dir(src_gems, gem_name, version, platform)

        # For pure Ruby gems not found in the target arch cache, try other arch caches.
        # Pure Ruby gems (no native extensions) are identical across architectures.
        unless gem_dir_name
          gem_dir_name, src_gems_override = find_gem_in_other_caches(gem_name, version, platform)
        end

        effective_src = src_gems_override || src_gems

        if gem_dir_name
          src_dir = File.join(effective_src, "gems", gem_dir_name)
          FileUtils.cp_r(src_dir, File.join(dst_gems, "gems", gem_dir_name))

          # Copy gemspec
          spec_file = "#{gem_dir_name}.gemspec"
          src_spec = File.join(effective_src, "specifications", spec_file)
          if File.exist?(src_spec)
            FileUtils.cp(src_spec, File.join(dst_gems, "specifications", spec_file))
          else
            vlog "⚠️  Gemspec not found: #{spec_file}"
          end

          vlog "  ✅ #{gem_dir_name}#{src_gems_override ? " (from #{File.basename(File.dirname(File.dirname(effective_src)))})" : ""}"
        else
          # Last resort: try to install from system Ruby's gem cache
          installed = install_gem_from_system(gem_name, version, dst_gems)
          log "   ⚠️  Gem not found in cache: #{gem_name}" unless installed
        end
      end

      # In --dev mode, overlay local Scarpe source on top of published gems
      overlay_dev_sources if @dev
    end

    def find_gem_in_other_caches(gem_name, version, platform)
      # Search other architecture caches for pure Ruby gems (macOS only)
      ARCH_MAP.values.uniq.each do |alt_arch|
        next if alt_arch == @arch

        alt_cache = File.join(@cache_dir, "traveling-ruby-#{TRAVELING_RUBY_VERSION}-macos-#{alt_arch}-full")
        alt_gems = File.join(alt_cache, "lib/ruby/gems/#{RUBY_ABI}")
        next unless Dir.exist?(alt_gems)

        gem_dir_name = find_gem_dir(alt_gems, gem_name, version, platform)
        return [gem_dir_name, alt_gems] if gem_dir_name
      end

      nil
    end

    def find_gem_in_other_caches_cross_platform(gem_name, version)
      # Search ALL platform caches for pure Ruby gems
      # This is useful when cross-building and gems are only in another platform's cache
      platforms = [
        "macos-x86_64",
        "macos-arm64",
        "linux-x86_64",
        "linux-arm64",
        "windows-x86_64",
        "windows-arm64",
      ]

      platforms.each do |platform_tag|
        alt_cache = File.join(@cache_dir, "traveling-ruby-#{TRAVELING_RUBY_VERSION}-#{platform_tag}-full")
        alt_gems = File.join(alt_cache, "lib/ruby/gems/#{RUBY_ABI}")
        next unless Dir.exist?(alt_gems)

        gem_dir_name = find_gem_dir(alt_gems, gem_name, version, nil)
        return [gem_dir_name, alt_gems] if gem_dir_name
      end

      nil
    end

    def install_gem_from_system(gem_name, version, dst_gems)
      # Try to find the gem in the system Ruby's gem cache and copy it
      system_gem_paths = [
        File.join(Dir.home, ".local/share/mise/installs/ruby/*/lib/ruby/gems/*/gems"),
        File.join(Dir.home, ".rbenv/versions/*/lib/ruby/gems/*/gems"),
        "/usr/local/lib/ruby/gems/*/gems",
      ]

      system_gem_paths.each do |pattern|
        Dir.glob(pattern).each do |gems_root|
          spec_root = File.join(File.dirname(gems_root), "specifications")
          gem_dir_name = find_gem_dir(File.dirname(gems_root), gem_name, version, nil)
          next unless gem_dir_name

          src_dir = File.join(gems_root, gem_dir_name)
          next unless Dir.exist?(src_dir)

          # Only copy pure Ruby gems (no native extensions in the gem dir)
          has_native = Dir.glob(File.join(src_dir, "**/*.{bundle,so,dll}")).any?
          next if has_native

          FileUtils.cp_r(src_dir, File.join(dst_gems, "gems", gem_dir_name))

          spec_file = "#{gem_dir_name}.gemspec"
          src_spec = File.join(spec_root, spec_file)
          if File.exist?(src_spec)
            FileUtils.cp(src_spec, File.join(dst_gems, "specifications", spec_file))
          end

          vlog "  ✅ #{gem_dir_name} (from system Ruby)"
          return true
        end
      end

      false
    end

    def overlay_dev_sources
      log "🔧 Overlaying development sources from #{@scarpe_root}..."
      dst_gems = File.join(app_path, "Contents/Resources/runtime/gems/gems")

      SCARPE_DEV_GEMS.each do |gem_name, config|
        src_lib = File.join(@scarpe_root, config[:lib])
        next unless Dir.exist?(src_lib)

        # Find the gem directory in the bundle
        gem_dir = Dir.glob(File.join(dst_gems, "#{gem_name}-*")).first
        next unless gem_dir

        dst_lib = File.join(gem_dir, "lib")
        if Dir.exist?(dst_lib)
          FileUtils.rm_rf(dst_lib)
          FileUtils.cp_r(src_lib, dst_lib)
          vlog "  🔄 #{gem_name}: overlaid with dev source from #{config[:lib]}"
        end
      end
    end

    def find_gem_dir(gems_root, name, version, platform)
      gems_dir = File.join(gems_root, "gems")

      # Try exact match with platform
      if platform && version
        candidate = "#{name}-#{version}-#{platform}"
        return candidate if Dir.exist?(File.join(gems_dir, candidate))
      end

      # Try exact match without platform
      if version
        candidate = "#{name}-#{version}"
        return candidate if Dir.exist?(File.join(gems_dir, candidate))
      end

      # Try to find any version
      matches = Dir.children(gems_dir).select { |d| d.start_with?("#{name}-") }
      # Prefer platform-specific if available
      if platform
        platform_match = matches.find { |d| d.include?(platform) }
        return platform_match if platform_match
      end

      matches.first
    end

    def copy_native_extensions
      log "🔧 Copying native extensions..."
      src_ext = File.join(runtime_cache_path, "lib/ruby/gems/#{RUBY_ABI}/extensions", ext_platform_dir, "#{RUBY_ABI}-static")
      dst_ext = File.join(app_path, "Contents/Resources/runtime/gems/extensions", ext_platform_dir, "#{RUBY_ABI}-static")

      return unless Dir.exist?(src_ext)

      FileUtils.mkdir_p(dst_ext)

      NATIVE_EXTENSION_GEMS.each do |gem_name|
        # Find the extension directory matching this gem
        matches = Dir.children(src_ext).select { |d| d.start_with?("#{gem_name}-") }
        matches.each do |ext_dir|
          FileUtils.cp_r(File.join(src_ext, ext_dir), File.join(dst_ext, ext_dir))
          vlog "  ✅ #{ext_dir}"
        end
      end
    end

    def copy_webview_extension
      log "🔧 Preparing webview_ruby native extension..."

      dst_gems = File.join(app_path, "Contents/Resources/runtime/gems/gems")
      webview_ext_dir = Dir.glob(File.join(dst_gems, "webview_ruby-*/ext")).first

      unless webview_ext_dir
        log "   ⚠️  webview_ruby gem directory not found in bundle"
        return
      end

      # Strategy: compile from source (preferred) or copy existing bundle (fallback)
      webview_src = find_webview_source
      if webview_src
        compile_webview_extension(webview_src, webview_ext_dir)
      else
        copy_existing_webview_bundle(webview_ext_dir)
      end
    end

    def find_webview_source
      # Look for webview.h + webview.cpp in the gem's ext directory
      search_patterns = [
        File.join(runtime_cache_path, "lib/ruby/gems/*/gems/webview_ruby-*/ext/webview/webview.h"),
        File.join(Dir.home, ".local/share/mise/installs/ruby/*/lib/ruby/gems/*/gems/webview_ruby-*/ext/webview/webview.h"),
        File.join(Dir.home, ".rbenv/versions/*/lib/ruby/gems/*/gems/webview_ruby-*/ext/webview/webview.h"),
      ]

      search_patterns.each do |pattern|
        matches = Dir.glob(pattern)
        return File.dirname(matches.first) if matches.any?
      end

      nil
    end

    def compile_webview_extension(src_dir, ext_dir)
      # The webview_ruby native extension links only against system frameworks
      # (WebKit, libc++, libSystem) — no libruby dependency. This means we can
      # cross-compile for any macOS architecture from any Mac.
      webview_cpp = File.join(src_dir, "webview.cpp")

      if @universal
        # Build universal binary (x86_64 + arm64)
        compile_webview_for_arch("x86_64", webview_cpp, ext_dir)
        compile_webview_for_arch("arm64", webview_cpp, ext_dir)
        create_universal_webview(ext_dir)
      else
        compile_webview_for_arch(@arch, webview_cpp, ext_dir)
      end
    end

    def compile_webview_for_arch(arch, webview_cpp, ext_dir)
      cache_path = File.join(@cache_dir, "webview-ext", "libwebview-ext-#{arch}.bundle")

      # Use cached build if available
      if File.exist?(cache_path)
        vlog "  Using cached webview extension for #{arch}"
        target_dir = File.join(ext_dir, "#{arch}-darwin")
        FileUtils.mkdir_p(target_dir)
        FileUtils.cp(cache_path, File.join(target_dir, "libwebview-ext.bundle"))
        return
      end

      log "   🔨 Compiling webview extension for #{arch}..."
      FileUtils.mkdir_p(File.dirname(cache_path))

      success = system(
        "xcrun", "-sdk", "macosx", "clang++",
        "-arch", arch,
        "-shared", "-dynamiclib",
        "-framework", "WebKit",
        "-std=c++11", "-O2",
        "-DWEBVIEW_COCOA",
        "-mmacosx-version-min=10.15",
        "-o", cache_path,
        webview_cpp,
        [:out, :err] => @verbose ? $stdout : File::NULL,
      )

      unless success
        log "   ⚠️  Compilation failed for #{arch} — falling back to existing bundle"
        return false
      end

      # Fix install name for embedding
      system("install_name_tool", "-id", "@loader_path/libwebview-ext.bundle", cache_path,
        [:out, :err] => File::NULL)

      target_dir = File.join(ext_dir, "#{arch}-darwin")
      FileUtils.mkdir_p(target_dir)
      FileUtils.cp(cache_path, File.join(target_dir, "libwebview-ext.bundle"))

      vlog "  ✅ Compiled webview extension for #{arch} (#{(File.size(cache_path) / 1024.0).round}KB)"
      true
    end

    def create_universal_webview(ext_dir)
      x86_path = File.join(ext_dir, "x86_64-darwin", "libwebview-ext.bundle")
      arm_path = File.join(ext_dir, "arm64-darwin", "libwebview-ext.bundle")

      return unless File.exist?(x86_path) && File.exist?(arm_path)

      # Create universal binary in both directories so FFI finds it regardless of arch
      universal_cache = File.join(@cache_dir, "webview-ext", "libwebview-ext-universal.bundle")
      system("lipo", "-create", x86_path, arm_path, "-output", universal_cache,
        [:out, :err] => File::NULL)

      if File.exist?(universal_cache)
        # Replace both arch-specific bundles with the universal one
        FileUtils.cp(universal_cache, x86_path)
        FileUtils.cp(universal_cache, arm_path)
        vlog "  ✅ Created universal binary (#{(File.size(universal_cache) / 1024.0).round}KB)"
      end
    end

    def copy_existing_webview_bundle(ext_dir)
      # Fallback: find a pre-compiled bundle on the system
      search_paths = [
        File.join(@cache_dir, "webview-ext", "libwebview-ext-#{@arch}.bundle"),
        File.join(@cache_dir, "webview-ext", "libwebview-ext-universal.bundle"),
        File.join(Dir.home, ".local/share/mise/installs/ruby/*/lib/ruby/gems/*/gems/webview_ruby-*/ext/*/libwebview-ext.bundle"),
        File.join(Dir.home, ".rbenv/versions/*/lib/ruby/gems/*/gems/webview_ruby-*/ext/*/libwebview-ext.bundle"),
        "/Library/Ruby/Gems/*/gems/webview_ruby-*/ext/*/libwebview-ext.bundle",
        "/usr/local/lib/ruby/gems/*/gems/webview_ruby-*/ext/*/libwebview-ext.bundle",
        "/opt/homebrew/lib/ruby/gems/*/gems/webview_ruby-*/ext/*/libwebview-ext.bundle",
        File.join(runtime_cache_path, "lib/ruby/gems/*/gems/webview_ruby-*/ext/*/libwebview-ext.bundle"),
      ]

      webview_bundle = nil
      search_paths.each do |pattern|
        matches = Dir.glob(pattern)
        arch_match = matches.find { |m| m.include?(@arch) || m.include?("universal") }
        webview_bundle = arch_match || matches.first
        break if webview_bundle
      end

      unless webview_bundle
        log "   ⚠️  webview_ruby native extension not found!"
        log "   The packaged app may not work. Install Xcode Command Line Tools for cross-compilation."
        return
      end

      target_dir = File.join(ext_dir, "#{@arch}-darwin")
      FileUtils.mkdir_p(target_dir)
      FileUtils.cp(webview_bundle, File.join(target_dir, "libwebview-ext.bundle"))
      vlog "  ✅ Copied #{File.basename(webview_bundle)} from #{File.dirname(webview_bundle)}"
    end

    def copy_user_app
      log "📄 Copying user application..."
      dst_app = File.join(app_path, "Contents/Resources/app")
      FileUtils.cp(@app_file, dst_app)

      app_dir = File.dirname(@app_file)

      # Only auto-copy assets if the app is in a dedicated directory
      # (not /tmp, home dir, or other shared system directories)
      require "tmpdir"
      shared_dirs = %w[/ /tmp /var/tmp]
      shared_dirs += [Dir.home, Dir.tmpdir]
      unless shared_dirs.include?(app_dir)
        # Copy asset files from the same directory
        asset_extensions = %w[png jpg jpeg gif svg ico css js html wav mp3 ogg ttf otf woff woff2]
        asset_extensions.each do |ext|
          Dir.glob(File.join(app_dir, "*.#{ext}")).each do |f|
            FileUtils.cp(f, dst_app)
            vlog "  Asset: #{File.basename(f)}"
          end
        end
      end

      # Copy well-known asset subdirectories regardless of parent dir
      %w[images assets fonts sounds].each do |subdir|
        src_dir = File.join(app_dir, subdir)
        if Dir.exist?(src_dir)
          FileUtils.cp_r(src_dir, File.join(dst_app, subdir))
          vlog "  Asset dir: #{subdir}/"
        end
      end
    end

    def write_boot_script
      boot_rb = <<~'RUBY'
        # Scarpe App Bootstrap — generated by scarpe package
        ENV['SCARPE_DISPLAY'] ||= 'wv_local'

        # Suppress CHANGELOG.md warning in packaged mode
        ENV['SCARPE_PACKAGED'] = '1'

        # In packaged mode, some optional gem dependencies may not be present
        # (e.g., nokogiri, sqlite3, fastimage are only loaded when actually used).
        # Relax RubyGems dependency checking so Scarpe can activate without them.
        module Gem
          class Specification
            alias_method :_packaged_activate_deps, :activate_dependencies
            def activate_dependencies
              _packaged_activate_deps
            rescue Gem::MissingSpecError
              # Optional dependency not present in bundle — acceptable
            end
          end
        end

        require 'scarpe'
        require 'scarpe/wv'

        app_file = ARGV[0] || raise("No app file specified!")
        Shoes.run_app(app_file)
      RUBY

      File.write(File.join(app_path, "Contents/Resources/boot.rb"), boot_rb)
    end

    def write_launcher
      launcher = <<~BASH
        #!/bin/bash
        # Scarpe App Launcher — generated by scarpe package
        set -e

        DIR="$(cd "$(dirname "$0")/../Resources"; pwd)"
        RUBY_ROOT="$DIR/runtime/ruby"
        GEMS_ROOT="$DIR/runtime/gems"

        # Save original environment for restore
        export ORIG_TERMINFO="$TERMINFO"
        export ORIG_SSL_CERT_DIR="$SSL_CERT_DIR"
        export ORIG_SSL_CERT_FILE="$SSL_CERT_FILE"
        export ORIG_RUBYOPT="$RUBYOPT"
        export ORIG_RUBYLIB="$RUBYLIB"

        # Configure Traveling Ruby environment
        export TERMINFO=/usr/share/terminfo
        export SSL_CERT_FILE="$RUBY_ROOT/lib/ca-bundle.crt"
        unset SSL_CERT_DIR

        export RUBYOPT="-rtraveling_ruby_restore_environment"
        export GEM_HOME="$GEMS_ROOT"
        export GEM_PATH="$GEMS_ROOT:$RUBY_ROOT/lib/ruby/gems/#{RUBY_ABI}"
        export RUBYLIB="$RUBY_ROOT/lib/ruby/site_ruby/#{RUBY_ABI}:$RUBY_ROOT/lib/ruby/site_ruby/#{RUBY_ABI}/#{ruby_platform_dir}:$RUBY_ROOT/lib/ruby/site_ruby:$RUBY_ROOT/lib/ruby/vendor_ruby/#{RUBY_ABI}:$RUBY_ROOT/lib/ruby/vendor_ruby/#{RUBY_ABI}/#{ruby_platform_dir}:$RUBY_ROOT/lib/ruby/vendor_ruby:$RUBY_ROOT/lib/ruby/#{RUBY_ABI}:$RUBY_ROOT/lib/ruby/#{RUBY_ABI}/#{ruby_platform_dir}"

        export SCARPE_DISPLAY=wv_local
        unset BUNDLE_GEMFILE BUNDLE_PATH BUNDLE_BIN_PATH

        # Find the user's app
        APP_FILE="$(find "$DIR/app" -name "*.rb" -maxdepth 1 | head -1)"
        if [ -z "$APP_FILE" ]; then
            osascript -e 'display dialog "No Shoes app found in this bundle!" with title "#{@name} — Error" buttons {"OK"} default button "OK" with icon stop'
            exit 1
        fi

        # Set working directory to the app folder so relative paths work
        cd "$DIR/app"

        # Launch!
        exec "$RUBY_ROOT/bin.real/ruby" "$DIR/boot.rb" "$APP_FILE"
      BASH

      launcher_path = File.join(app_path, "Contents/MacOS/scarpe-launcher")
      File.write(launcher_path, launcher)
      FileUtils.chmod(0o755, launcher_path)
    end

    def write_info_plist
      plist = <<~PLIST
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleDevelopmentRegion</key>
            <string>en</string>
            <key>CFBundleExecutable</key>
            <string>scarpe-launcher</string>
            <key>CFBundleIdentifier</key>
            <string>#{@bundle_id}</string>
            <key>CFBundleInfoDictionaryVersion</key>
            <string>6.0</string>
            <key>CFBundleName</key>
            <string>#{@name}</string>
            <key>CFBundleDisplayName</key>
            <string>#{@name}</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0.0</string>
            <key>CFBundleVersion</key>
            <string>1</string>
            <key>LSMinimumSystemVersion</key>
            <string>10.15</string>
            <key>NSHighResolutionCapable</key>
            <true/>
            <key>NSSupportsAutomaticGraphicsSwitching</key>
            <true/>
            #{icon_plist_entry}
        </dict>
        </plist>
      PLIST

      File.write(File.join(app_path, "Contents/Info.plist"), plist)
    end

    def icon_plist_entry
      return "" unless @icon

      icon_name = File.basename(@icon, File.extname(@icon))
      <<~PLIST.strip
        <key>CFBundleIconFile</key>
            <string>#{icon_name}</string>
      PLIST
    end

    def copy_icon
      return unless @icon && File.exist?(@icon)

      dst = File.join(app_path, "Contents/Resources", File.basename(@icon))

      if @icon.end_with?(".icns")
        FileUtils.cp(@icon, dst)
      elsif @icon.end_with?(".png")
        # Convert PNG to ICNS using sips (macOS built-in)
        icns_path = File.join(app_path, "Contents/Resources", "#{File.basename(@icon, '.png')}.icns")
        iconset = File.join(@cache_dir, "icon.iconset")
        FileUtils.mkdir_p(iconset)

        # Generate required icon sizes
        sizes = [16, 32, 64, 128, 256, 512]
        sizes.each do |size|
          system("sips", "-z", size.to_s, size.to_s, @icon, "--out", File.join(iconset, "icon_#{size}x#{size}.png"),
            [:out, :err] => File::NULL)
          double = size * 2
          if double <= 1024
            system("sips", "-z", double.to_s, double.to_s, @icon, "--out", File.join(iconset, "icon_#{size}x#{size}@2x.png"),
              [:out, :err] => File::NULL)
          end
        end

        system("iconutil", "-c", "icns", iconset, "-o", icns_path)
        FileUtils.rm_rf(iconset)

        log "   🎨 Converted PNG to ICNS"
      else
        log "   ⚠️  Unsupported icon format: #{File.extname(@icon)} (use .icns or .png)"
      end
    end

    def strip_unnecessary_files
      log "🗑️  Stripping unnecessary files..."
      gems_dir = File.join(app_path, "Contents/Resources/runtime/gems/gems")
      ruby_dir = File.join(app_path, "Contents/Resources/runtime/ruby")

      # --- Gem cleanup ---

      # Remove test/spec/doc directories
      removable_dirs = %w[test spec examples docs doc .git spikes experiments benchmark features yard]
      removable_dirs.each do |dir_name|
        Dir.glob(File.join(gems_dir, "**", dir_name)).each do |dir|
          next unless File.directory?(dir)
          FileUtils.rm_rf(dir)
        end
      end

      # Remove C source files and build artifacts (keep .bundle files!)
      %w[*.o *.c *.h *.cpp *.cxx Makefile mkmf.log].each do |pattern|
        Dir.glob(File.join(gems_dir, "**", pattern)).each do |f|
          File.delete(f) if File.file?(f)
        end
      end

      # Remove meta-files at gem root level
      %w[README* CHANGELOG* CHANGES* HISTORY* LICENSE* COPYING* NEWS* TODO* CLAUDE.md CONTRIBUTING.md CODE_OF_CONDUCT.md *.gemspec Gemfile Gemfile.lock Rakefile dev.yml].each do |pattern|
        Dir.glob(File.join(gems_dir, "*", pattern)).each do |f|
          File.delete(f) if File.file?(f)
        end
      end

      # Remove nested gem copies (scarpe gem bundles scarpe-components and lacci)
      %w[scarpe-components lacci].each do |nested|
        nested_dir = Dir.glob(File.join(gems_dir, "scarpe-*/#{nested}")).first
        FileUtils.rm_rf(nested_dir) if nested_dir && Dir.exist?(nested_dir)
      end

      # Remove non-essential gem directories
      %w[bin sig tasks scarpegen.rb].each do |dir_name|
        Dir.glob(File.join(gems_dir, "*", dir_name)).each do |d|
          FileUtils.rm_rf(d)
        end
      end

      # Strip dSYM directories from native extensions (debug symbols)
      Dir.glob(File.join(app_path, "**", "*.dSYM")).each do |dsym|
        FileUtils.rm_rf(dsym)
      end

      # Remove unused Ruby version-specific native extensions from platform gems
      # Platform gems like nokogiri ship bundles for Ruby 2.7, 3.0, 3.1, 3.2, 3.3, 3.4
      # We only need the one matching our Ruby ABI major.minor
      ruby_mm = TRAVELING_RUBY_VERSION.split(".")[0..1].join(".")  # "3.4"
      strip_platform_gem_versions(gems_dir, ruby_mm)

      # --- FFI source cleanup ---

      # FFI gem ships C source code and build artifacts (~2.7MB) not needed at runtime
      ffi_ext = Dir.glob(File.join(gems_dir, "ffi-*/ext")).first
      FileUtils.rm_rf(ffi_ext) if ffi_ext

      # --- Bootstrap theme cleanup ---

      # scarpe-components ships 26 Bootstrap themes (~7MB) but Calzini (default renderer)
      # doesn't use them. Keep only one theme for Tiranti compatibility.
      theme_dir = Dir.glob(File.join(gems_dir, "scarpe-components-*/assets/bootstrap-themes")).first
      if theme_dir && Dir.exist?(theme_dir)
        keep_files = %w[bootstrap-flatly.css bootstrap.bundle.min.js bootstrap-icons.min.css]
        Dir.children(theme_dir).each do |f|
          next if keep_files.include?(f)
          path = File.join(theme_dir, f)
          File.delete(path) if File.file?(path)
          vlog "  Removed theme: #{f}"
        end
      end

      # --- Ruby stdlib cleanup ---

      # Remove stdlib modules not needed at runtime
      stdlib_removable = %w[rdoc irb reline debug rbs ruby_vm rinda drb rss rexml bundler prism syntax_suggest did_you_mean error_highlight]
      stdlib_dir = File.join(ruby_dir, "lib/ruby/#{RUBY_ABI}")
      stdlib_removable.each do |lib|
        path = File.join(stdlib_dir, lib)
        FileUtils.rm_rf(path) if Dir.exist?(path)
        rb_file = File.join(stdlib_dir, "#{lib}.rb")
        File.delete(rb_file) if File.exist?(rb_file)
      end

      # --- Terminal/ncurses dylib cleanup ---

      # GUI apps don't need terminal libraries
      terminal_dylibs = %w[libreadline.dylib libtermcap.dylib libncurses.dylib libncurses.6.dylib
                           libedit.dylib libedit.0.dylib libform.dylib libform.6.dylib
                           libmenu.dylib libmenu.6.dylib libpanel.dylib libpanel.6.dylib]
      ruby_lib_dir = File.join(ruby_dir, "lib")
      terminal_dylibs.each do |dylib|
        path = File.join(ruby_lib_dir, dylib)
        File.delete(path) if File.exist?(path) && !File.symlink?(path)
        File.delete(path) if File.symlink?(path)
      end

      # --- Encoding bundle cleanup ---

      # Remove unused encoding bundles (Scarpe only needs encdb + transdb)
      ext_dir = File.join(stdlib_dir, ruby_platform_dir)
      if Dir.exist?(ext_dir)
        # Remove all individual encoding bundles (enc/*.bundle except encdb.bundle)
        enc_dir = File.join(ext_dir, "enc")
        if Dir.exist?(enc_dir)
          Dir.glob(File.join(enc_dir, "*.bundle")).each do |f|
            next if File.basename(f) == "encdb.bundle"
            File.delete(f)
          end
          # Remove encoding transcoder bundles (enc/trans/*.bundle except transdb.bundle)
          trans_dir = File.join(enc_dir, "trans")
          if Dir.exist?(trans_dir)
            Dir.glob(File.join(trans_dir, "*.bundle")).each do |f|
              next if File.basename(f) == "transdb.bundle"
              File.delete(f)
            end
          end
        end

        # Remove other unused native extensions
        %w[ripper.bundle pty.bundle objspace.bundle continuation.bundle
           io/console.bundle rbconfig/sizeof.bundle].each do |ext|
          path = File.join(ext_dir, ext)
          File.delete(path) if File.exist?(path)
        end
      end

      # Deduplicate dylibs (replace versioned copies with symlinks)
      dedup_dylibs(File.join(ruby_dir, "lib"))

      # --- Minimal mode: aggressive stripping ---
      if @minimal
        strip_minimal(gems_dir, ruby_dir)
      end

      # Remove bundler from site_ruby (2.2MB, never used in packaged mode)
      site_ruby_dir = File.join(ruby_dir, "lib/ruby/site_ruby/#{RUBY_ABI}")
      %w[bundler bundler.rb].each do |f|
        path = File.join(site_ruby_dir, f)
        FileUtils.rm_rf(path) if File.exist?(path) || Dir.exist?(path)
      end

      final_size = `du -sh "#{app_path}" 2>/dev/null`.strip.split("\t").first
      vlog "  Stripped to #{final_size}"
    end

    def strip_minimal(gems_dir, ruby_dir)
      log "🔪 Minimal mode: stripping optional dependencies..."

      # Remove optional gems (nokogiri, sqlite3, fastimage, rake)
      OPTIONAL_GEMS.each do |gem_name|
        Dir.glob(File.join(gems_dir, "#{gem_name}-*")).each do |d|
          FileUtils.rm_rf(d)
          vlog "  Removed gem: #{File.basename(d)}"
        end
        # Also remove from specifications
        specs_dir = File.join(File.dirname(gems_dir), "specifications")
        Dir.glob(File.join(specs_dir, "#{gem_name}-*")).each do |s|
          File.delete(s) if File.file?(s)
        end
      end

      # Remove SSL/crypto dylibs (8MB — only needed for download/HTTPS)
      ruby_lib_dir = File.join(ruby_dir, "lib")
      ssl_dylibs = Dir.glob(File.join(ruby_lib_dir, "libcrypto*")) +
                   Dir.glob(File.join(ruby_lib_dir, "libssl*"))
      saved = 0
      ssl_dylibs.each do |f|
        saved += File.symlink?(f) ? 0 : File.size(f)
        File.delete(f)
      end
      vlog "  Removed SSL dylibs: #{(saved / 1024.0 / 1024.0).round(1)}MB"

      # Remove CA certificates (no HTTPS = no certs needed)
      ca_cert = File.join(ruby_lib_dir, "ca-bundle.crt")
      File.delete(ca_cert) if File.exist?(ca_cert)

      # Remove stdlib modules not needed without network/SSL
      stdlib_dir = File.join(ruby_dir, "lib/ruby/#{RUBY_ABI}")
      MINIMAL_STRIP_STDLIB.each do |lib|
        path = File.join(stdlib_dir, lib)
        FileUtils.rm_rf(path) if Dir.exist?(path)
        rb_file = File.join(stdlib_dir, "#{lib}.rb")
        File.delete(rb_file) if File.exist?(rb_file)
      end

      # Remove additional large files not needed at runtime
      stripped_files = 0
      MINIMAL_STRIP_FILES.each do |filename|
        path = File.join(stdlib_dir, filename)
        if File.exist?(path)
          stripped_files += File.size(path)
          File.delete(path)
        end
      end
      vlog "  Removed #{MINIMAL_STRIP_FILES.count} dev files: #{(stripped_files / 1024.0).round}KB" if stripped_files > 0

      # Remove corresponding native extensions
      ext_dir = File.join(stdlib_dir, ruby_platform_dir)
      %w[openssl.bundle fiddle.bundle].each do |ext|
        path = File.join(ext_dir, ext)
        File.delete(path) if File.exist?(path)
      end

      # Remove unicode_normalize (228KB, rarely needed)
      FileUtils.rm_rf(File.join(stdlib_dir, "unicode_normalize"))

      # Remove rubygems/commands (232KB × 2 = 464KB — only needed for `gem` CLI)
      rubygems_commands_saved = 0
      [stdlib_dir, File.join(ruby_dir, "lib/ruby/site_ruby/#{RUBY_ABI}")].each do |base|
        cmd_dir = File.join(base, "rubygems/commands")
        if Dir.exist?(cmd_dir)
          rubygems_commands_saved += dir_size(cmd_dir)
          FileUtils.rm_rf(cmd_dir)
        end
      end
      vlog "  Removed rubygems/commands: #{(rubygems_commands_saved / 1024.0).round}KB" if rubygems_commands_saved > 0

      # Remove rubygems/resolver (dependency resolution — not needed at runtime)
      [stdlib_dir, File.join(ruby_dir, "lib/ruby/site_ruby/#{RUBY_ABI}")].each do |base|
        resolver_dir = File.join(base, "rubygems/resolver")
        FileUtils.rm_rf(resolver_dir) if Dir.exist?(resolver_dir)
      end

      # Remove rubygems/ext (extension building — not needed at runtime)
      [stdlib_dir, File.join(ruby_dir, "lib/ruby/site_ruby/#{RUBY_ABI}")].each do |base|
        ext_dir = File.join(base, "rubygems/ext")
        FileUtils.rm_rf(ext_dir) if Dir.exist?(ext_dir)
      end

      # Remove rubygems/vendor (bundled dependencies — 748KB, mostly not needed)
      vendor_saved = 0
      [stdlib_dir, File.join(ruby_dir, "lib/ruby/site_ruby/#{RUBY_ABI}")].each do |base|
        vendor_dir = File.join(base, "rubygems/vendor")
        if Dir.exist?(vendor_dir)
          vendor_saved += dir_size(vendor_dir)
          FileUtils.rm_rf(vendor_dir)
        end
      end
      vlog "  Removed rubygems/vendor: #{(vendor_saved / 1024.0).round}KB" if vendor_saved > 0

      # Remove other rubygems modules not needed at runtime
      rubygems_extras = %w[
        installer.rb uninstaller.rb package package.rb
        request_set request_set.rb security security.rb
        gemcutter_utilities.rb remote_fetcher.rb
        source source.rb source_list.rb
      ]
      extras_saved = 0
      [stdlib_dir, File.join(ruby_dir, "lib/ruby/site_ruby/#{RUBY_ABI}")].each do |base|
        rubygems_extras.each do |item|
          path = File.join(base, "rubygems", item)
          if File.exist?(path) || Dir.exist?(path)
            extras_saved += File.directory?(path) ? dir_size(path) : File.size(path)
            FileUtils.rm_rf(path)
          end
        end
      end
      vlog "  Removed rubygems extras: #{(extras_saved / 1024.0).round}KB" if extras_saved > 0
    end

    def strip_platform_gem_versions(gems_dir, target_version)
      # Platform gems ship per-Ruby-version native extensions
      # Remove all except the target version (or the highest available)
      Dir.glob(File.join(gems_dir, "*-{x86_64,arm64}-darwin*")).each do |gem_dir|
        lib_dir = File.join(gem_dir, "lib")
        next unless Dir.exist?(lib_dir)

        # Look for versioned subdirectories (e.g., lib/nokogiri/3.2/)
        Dir.children(lib_dir).each do |subdir|
          sub_path = File.join(lib_dir, subdir)
          next unless Dir.exist?(sub_path)

          versions = Dir.children(sub_path).select { |d| d.match?(/^\d+\.\d+$/) }
          next if versions.empty?

          keep = versions.include?(target_version) ? target_version : versions.max
          versions.each do |v|
            next if v == keep
            FileUtils.rm_rf(File.join(sub_path, v))
            vlog "  Removed #{File.basename(gem_dir)}/#{subdir}/#{v}/ (keeping #{keep})"
          end
        end
      end
    end

    def dedup_dylibs(lib_dir)
      # Traveling Ruby ships duplicate dylibs (e.g., libcrypto.3.dylib AND libcrypto.dylib)
      # Replace the unversioned copy with a symlink to the versioned one
      seen = {}
      Dir.glob(File.join(lib_dir, "*.dylib")).sort.each do |path|
        size = File.size(path)
        base = File.basename(path)

        # Group by library name (e.g., "libcrypto")
        lib_name = base.sub(/\.[\d.]*\.dylib$/, "").sub(/\.dylib$/, "")
        seen[lib_name] ||= []
        seen[lib_name] << { path: path, base: base, size: size }
      end

      saved = 0
      seen.each do |lib_name, entries|
        next if entries.length < 2

        # Keep the versioned one (longer name), symlink the shorter name
        entries.sort_by! { |e| -e[:base].length }
        versioned = entries.first
        entries[1..].each do |entry|
          next unless entry[:size] == versioned[:size]  # Only if same size (likely identical)
          File.delete(entry[:path])
          File.symlink(versioned[:base], entry[:path])
          saved += entry[:size]
        end
      end

      vlog "  Deduped dylibs: saved #{(saved / 1024.0 / 1024.0).round(1)}MB" if saved > 0
    end

    # --- Code Signing ---

    def sign_bundle
      log "🔏 Code signing..."

      # Ad-hoc signing (no Apple Developer account required)
      # Uses "-" as identity which creates an ad-hoc signature.
      # This tells macOS the code hasn't been tampered with, reducing
      # Gatekeeper friction. Not the same as a full Developer ID signature
      # but significantly better than no signature.

      # Sign all native extensions and dylibs first (deep signing)
      native_files = Dir.glob(File.join(app_path, "**/*.bundle")) +
                     Dir.glob(File.join(app_path, "**/*.dylib"))

      native_files.each do |f|
        next if File.symlink?(f)
        system("codesign", "--force", "--sign", "-",
          "--timestamp=none",
          f,
          [:out, :err] => @verbose ? $stdout : File::NULL)
      end

      # Sign the Ruby binary
      ruby_bin = File.join(app_path, "Contents/Resources/runtime/ruby/bin.real/ruby")
      if File.exist?(ruby_bin)
        system("codesign", "--force", "--sign", "-",
          "--timestamp=none",
          "--entitlements", write_entitlements,
          ruby_bin,
          [:out, :err] => @verbose ? $stdout : File::NULL)
      end

      # Sign the whole .app bundle
      success = system("codesign", "--force", "--deep", "--sign", "-",
        "--timestamp=none",
        "--entitlements", write_entitlements,
        app_path,
        [:out, :err] => @verbose ? $stdout : File::NULL)

      if success
        log "   ✅ Ad-hoc code signed"
        # Verify
        verify = `codesign --verify --verbose=2 "#{app_path}" 2>&1`
        if verify.include?("valid on disk")
          vlog "  Signature verified: valid on disk"
        else
          vlog "  Verification output: #{verify.strip}"
        end
      else
        log "   ⚠️  Code signing failed (app will still work, but Gatekeeper may warn)"
      end

      # Clean up temp entitlements
      ent_file = File.join(@cache_dir, "entitlements.plist")
      File.delete(ent_file) if File.exist?(ent_file)
    end

    def write_entitlements
      ent_path = File.join(@cache_dir, "entitlements.plist")
      FileUtils.mkdir_p(@cache_dir)

      # Minimal entitlements for a GUI app using WebKit
      File.write(ent_path, <<~PLIST)
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
            <true/>
            <key>com.apple.security.cs.allow-jit</key>
            <true/>
        </dict>
        </plist>
      PLIST

      ent_path
    end

    # --- DMG Builder ---

    def create_dmg
      log "💿 Creating DMG..."
      dmg_path = File.join(@output_dir, "#{@name}.dmg")
      FileUtils.rm_f(dmg_path)

      # Create a temporary directory for the DMG contents
      dmg_staging = File.join(@cache_dir, "dmg-staging")
      FileUtils.rm_rf(dmg_staging)
      FileUtils.mkdir_p(dmg_staging)

      # Copy .app into staging
      FileUtils.cp_r(app_path, File.join(dmg_staging, "#{@name}.app"))

      # Create Applications symlink for drag-to-install
      File.symlink("/Applications", File.join(dmg_staging, "Applications"))

      # Create DMG using hdiutil
      # Uses UDZO (zlib compressed) for good compression
      success = system(
        "hdiutil", "create",
        "-volname", @name,
        "-srcfolder", dmg_staging,
        "-ov",        # overwrite
        "-format", "UDZO",  # zlib compressed
        "-imagekey", "zlib-level=9",
        dmg_path,
        [:out, :err] => @verbose ? $stdout : File::NULL,
      )

      FileUtils.rm_rf(dmg_staging)

      if success && File.exist?(dmg_path)
        dmg_size = (File.size(dmg_path) / 1024.0 / 1024.0).round(1)
        log "   ✅ Created #{File.basename(dmg_path)} (#{dmg_size}MB)"
        dmg_path
      else
        log "   ⚠️  DMG creation failed"
        nil
      end
    end

    # --- Linux AppImage Builder ---

    def create_appimage_structure
      log "📦 Creating AppDir structure..."
      FileUtils.rm_rf(appdir_path)

      # AppImage standard structure
      dirs = [
        appdir_path,
        File.join(appdir_path, "usr/bin"),
        File.join(appdir_path, "usr/lib/ruby"),
        File.join(appdir_path, "usr/share/#{@name.downcase}"),
        File.join(appdir_path, "usr/share/icons/hicolor/256x256/apps"),
      ]

      dirs.each { |d| FileUtils.mkdir_p(d) }
      vlog "Created AppDir structure"
    end

    def copy_ruby_runtime_linux
      log "📥 Copying Ruby runtime (Linux)..."

      src = runtime_cache_path
      dst_bin = File.join(appdir_path, "usr/bin")
      dst_lib = File.join(appdir_path, "usr/lib")

      # Copy Ruby binary
      ruby_src = File.join(src, "bin.real", "ruby")
      ruby_src = File.join(src, "bin", "ruby") unless File.exist?(ruby_src)
      FileUtils.cp(ruby_src, File.join(dst_bin, "ruby"))
      FileUtils.chmod(0755, File.join(dst_bin, "ruby"))

      # Copy Ruby stdlib (but NOT gems - we copy those separately)
      # This copies lib/ruby/3.4.0 (stdlib), lib/ruby/site_ruby, etc.
      # but skips lib/ruby/gems which we handle in copy_gems_linux
      stdlib_src = File.join(src, "lib", "ruby")
      dst_ruby = File.join(dst_lib, "ruby")
      FileUtils.mkdir_p(dst_ruby)

      Dir[File.join(stdlib_src, "*")].each do |item|
        item_name = File.basename(item)
        # Skip gems directory - we copy only required gems separately
        next if item_name == "gems"
        FileUtils.cp_r(item, dst_ruby)
      end

      # Create empty gems structure (populated by copy_gems_linux)
      FileUtils.mkdir_p(File.join(dst_ruby, "gems", RUBY_ABI, "gems"))
      FileUtils.mkdir_p(File.join(dst_ruby, "gems", RUBY_ABI, "specifications"))
      FileUtils.mkdir_p(File.join(dst_ruby, "gems", RUBY_ABI, "extensions"))

      # Copy shared libraries (*.so)
      Dir[File.join(src, "lib", "*.so*")].each do |so|
        FileUtils.cp(so, dst_lib) unless File.symlink?(so)
      end

      vlog "Copied Ruby runtime"
    end

    def copy_gems_linux
      log "📚 Copying gems (Linux)..."

      # Note: find_gem_dir expects the parent directory and adds "/gems" internally
      src_gems_root = File.join(runtime_cache_path, "lib", "ruby", "gems", RUBY_ABI)
      src_gems = File.join(src_gems_root, "gems")
      src_specs = File.join(src_gems_root, "specifications")

      dst_gems = File.join(appdir_path, "usr/lib/ruby/gems", RUBY_ABI, "gems")
      dst_specs = File.join(appdir_path, "usr/lib/ruby/gems", RUBY_ABI, "specifications")

      FileUtils.mkdir_p(dst_gems)
      FileUtils.mkdir_p(dst_specs)

      gems_copied = []

      REQUIRED_GEMS.each do |gem_name, version, _platform|
        next if @minimal && OPTIONAL_GEMS.include?(gem_name)

        gem_dir_name = find_gem_dir(src_gems_root, gem_name, version, nil)
        if gem_dir_name
          gem_full_path = File.join(src_gems, gem_dir_name)
          FileUtils.cp_r(gem_full_path, dst_gems) if Dir.exist?(gem_full_path)
          gems_copied << gem_dir_name

          spec_file = File.join(src_specs, "#{gem_dir_name}.gemspec")
          FileUtils.cp(spec_file, dst_specs) if File.exist?(spec_file)
        else
          # Try other platform caches (macOS cache has pure-ruby Scarpe gems)
          result = find_gem_in_other_caches_cross_platform(gem_name, version)
          if result
            alt_gem_dir, alt_gems_root = result
            alt_gem_path = File.join(alt_gems_root, "gems", alt_gem_dir)
            FileUtils.cp_r(alt_gem_path, dst_gems) if Dir.exist?(alt_gem_path)
            gems_copied << alt_gem_dir

            alt_spec = File.join(alt_gems_root, "specifications", "#{alt_gem_dir}.gemspec")
            FileUtils.cp(alt_spec, dst_specs) if File.exist?(alt_spec)
          else
            vlog "⚠️  Could not find gem: #{gem_name}"
          end
        end
      end

      vlog "Copied #{gems_copied.length} gems"

      overlay_dev_sources_linux if @dev
    end

    def overlay_dev_sources_linux
      # Similar to macOS overlay but for Linux paths
      SCARPE_DEV_GEMS.each do |gem_name, paths|
        src_lib = File.join(@scarpe_root, paths[:lib])
        next unless File.directory?(src_lib)

        dst_gems = File.join(appdir_path, "usr/lib/ruby/gems", RUBY_ABI, "gems")
        gem_dir = Dir[File.join(dst_gems, "#{gem_name}-*")].first
        next unless gem_dir

        dst_lib = File.join(gem_dir, "lib")
        FileUtils.rm_rf(dst_lib)
        FileUtils.cp_r(src_lib, gem_dir)
        vlog "Overlaid #{gem_name} with dev source"
      end
    end

    def copy_native_extensions_linux
      log "🔧 Copying native extensions (Linux)..."

      # Linux Traveling Ruby uses "3.4.0-static" for the version directory
      src_ext = File.join(runtime_cache_path, "lib", "ruby", "gems", RUBY_ABI, "extensions", ext_platform_dir, "#{RUBY_ABI}-static")
      dst_ext = File.join(appdir_path, "usr/lib/ruby/gems", RUBY_ABI, "extensions", ext_platform_dir, "#{RUBY_ABI}-static")

      unless Dir.exist?(src_ext)
        vlog "No native extensions directory found at #{src_ext}"
        return
      end

      FileUtils.mkdir_p(dst_ext)

      NATIVE_EXTENSION_GEMS.each do |gem|
        next if @minimal && OPTIONAL_GEMS.include?(gem)

        gem_ext = Dir[File.join(src_ext, "#{gem}-*")].first
        if gem_ext
          FileUtils.cp_r(gem_ext, dst_ext)
          vlog "Copied #{gem} native extension"
        end
      end
    end

    def copy_webview_extension_linux
      log "🖼️  Copying webview extension (Linux)..."

      ext_dir = File.join(appdir_path, "usr/lib/ruby/gems", RUBY_ABI, "gems", "webview_ruby-0.1.2", "ext", ext_platform_dir)
      FileUtils.mkdir_p(ext_dir)

      # Check for pre-built extension in cache
      cached_ext = File.join(@cache_dir, "webview-ext", "libwebview-ext-#{platform_string}.so")

      if File.exist?(cached_ext)
        FileUtils.cp(cached_ext, File.join(ext_dir, "libwebview-ext.so"))
        vlog "Copied pre-built webview extension"
      elsif @skip_webview_check
        warn "⚠️  Skipping webview extension (--skip-webview-check) - app will NOT run!"
        vlog "Creating placeholder for webview extension"
        # Create a placeholder so the directory structure is complete
        File.write(File.join(ext_dir, "libwebview-ext.so"), "# PLACEHOLDER - compile and replace this file\n")
      else
        raise <<~ERROR
          Missing pre-built webview extension for #{platform_string}.

          The webview native extension must be compiled on a Linux system with
          GTK and WebKitGTK development packages installed.

          To build manually:
            c++ -shared -fPIC -O2 \\
              $(pkg-config --cflags gtk+-3.0 webkit2gtk-4.1) \\
              -DWEBVIEW_GTK \\
              -o libwebview-ext.so \\
              webview.cpp \\
              $(pkg-config --libs gtk+-3.0 webkit2gtk-4.1)

          Place the compiled .so in: #{File.dirname(cached_ext)}/

          Tip: Use --skip-webview-check to build anyway (for testing structure).
        ERROR
      end
    end

    def copy_user_app_linux
      log "📄 Copying user app..."

      app_dir = File.join(appdir_path, "usr/share/#{@name.downcase}")
      FileUtils.cp(@app_file, File.join(app_dir, "main.rb"))

      # Copy any assets from the same directory
      app_source_dir = File.dirname(@app_file)
      %w[*.png *.jpg *.jpeg *.gif *.svg *.ico *.ttf *.otf *.woff *.woff2 *.css *.js *.html].each do |pattern|
        Dir[File.join(app_source_dir, pattern)].each do |asset|
          FileUtils.cp(asset, app_dir)
        end
      end

      vlog "Copied user application"
    end

    def write_boot_script_linux
      boot_rb = File.join(appdir_path, "usr/share/#{@name.downcase}/boot.rb")

      File.write(boot_rb, <<~RUBY)
        # Boot script for packaged Scarpe app (Linux)
        # Auto-generated by scarpe package

        # Relax dependency checking for packaged apps
        module Gem
          class Specification
            alias_method :_packaged_activate_deps, :activate_dependencies
            def activate_dependencies
              _packaged_activate_deps
            rescue Gem::MissingSpecError
              # Optional dependency not present in bundle
            end
          end
        end

        # Suppress changelog warning
        ENV["SCARPE_SILENCE_CHANGELOG"] = "1"
        ENV["SCARPE_DISPLAY"] = "wv_local"

        require "scarpe"
        require "scarpe/wv"

        # Load and run the app
        load File.join(__dir__, "main.rb")
      RUBY

      vlog "Wrote boot.rb"
    end

    def write_apprun_script
      apprun = File.join(appdir_path, "AppRun")

      File.write(apprun, <<~BASH)
        #!/bin/bash
        # AppRun script for #{@name}
        # Auto-generated by scarpe package

        SELF=$(readlink -f "$0")
        HERE=${SELF%/*}

        # Check for WebKitGTK
        if ! pkg-config --exists webkit2gtk-4.1 2>/dev/null && ! pkg-config --exists webkit2gtk-4.0 2>/dev/null; then
          echo "Error: WebKitGTK is required but not installed."
          echo ""
          echo "Install it with:"
          echo "  Ubuntu/Debian: sudo apt install libwebkit2gtk-4.1-0"
          echo "  Fedora:        sudo dnf install webkit2gtk4.1"
          echo "  Arch:          sudo pacman -S webkit2gtk"
          exit 1
        fi

        # Set up Ruby environment
        export PATH="$HERE/usr/bin:$PATH"
        export LD_LIBRARY_PATH="$HERE/usr/lib:$LD_LIBRARY_PATH"
        export GEM_HOME="$HERE/usr/lib/ruby/gems/#{RUBY_ABI}"
        export GEM_PATH="$GEM_HOME"
        # Include platform dir (x86_64-linux or aarch64-linux) for rbconfig.rb
        PLATFORM_DIR=$(uname -m)-linux
        export RUBYLIB="$HERE/usr/lib/ruby/#{RUBY_ABI}/$PLATFORM_DIR:$HERE/usr/lib/ruby/#{RUBY_ABI}:$HERE/usr/lib/ruby/site_ruby/#{RUBY_ABI}:$HERE/usr/lib/ruby/vendor_ruby/#{RUBY_ABI}"
        export RUBYOPT="-r$HERE/usr/lib/ruby/site_ruby/traveling_ruby_restore_environment.rb"

        # Run the app
        cd "$HERE/usr/share/#{@name.downcase}"
        exec "$HERE/usr/bin/ruby" boot.rb "$@"
      BASH

      FileUtils.chmod(0755, apprun)
      vlog "Wrote AppRun script"
    end

    def write_desktop_file
      desktop_file = File.join(appdir_path, "#{@name.downcase}.desktop")

      File.write(desktop_file, <<~DESKTOP)
        [Desktop Entry]
        Type=Application
        Name=#{@name}
        Exec=AppRun
        Icon=#{@name.downcase}
        Categories=Utility;
        Comment=A Shoes/Scarpe application
        Terminal=false
      DESKTOP

      # Symlink to root (required by AppImage)
      FileUtils.ln_sf("#{@name.downcase}.desktop", File.join(appdir_path, ".DirIcon"))

      vlog "Wrote desktop file"
    end

    def copy_icon_linux
      return unless @icon && File.exist?(@icon)

      icon_dest = File.join(appdir_path, "usr/share/icons/hicolor/256x256/apps/#{@name.downcase}.png")

      if @icon.end_with?(".png")
        FileUtils.cp(@icon, icon_dest)
      elsif @icon.end_with?(".svg")
        # Try to convert SVG to PNG using ImageMagick if available
        if system("which convert >/dev/null 2>&1")
          system("convert", "-resize", "256x256", @icon, icon_dest, [:out, :err] => File::NULL)
        end
      end

      # Also put icon at AppDir root
      FileUtils.cp(icon_dest, File.join(appdir_path, "#{@name.downcase}.png")) if File.exist?(icon_dest)

      vlog "Copied application icon"
    end

    def strip_unnecessary_files_linux
      log "🗑️  Stripping unnecessary files..."

      gems_dir = File.join(appdir_path, "usr/lib/ruby/gems", RUBY_ABI, "gems")
      ruby_dir = File.join(appdir_path, "usr/lib/ruby")

      # Remove development files (be careful not to delete code files like changelog.rb!)
      patterns = %w[
        **/test/**
        **/spec/**
        **/tests/**
        **/CHANGELOG.md
        **/README.md
        **/LICENSE
        **/LICENSE.txt
        **/Rakefile
        **/Gemfile*
        **/.git*
        **/.rubocop*
      ]

      patterns.each do |pattern|
        Dir.glob(File.join(gems_dir, pattern)).each do |f|
          FileUtils.rm_rf(f)
        end
      end

      # Additional minimal stripping
      strip_minimal(gems_dir, ruby_dir) if @minimal

      vlog "Stripped unnecessary files"
    end

    def create_appimage
      log "📦 Creating AppImage..."

      # Check for appimagetool
      appimagetool = find_appimagetool

      unless appimagetool
        log "   ⚠️  appimagetool not found. Creating .tar.gz instead."
        return create_appdir_tarball
      end

      appimage_file = appimage_path
      FileUtils.rm_f(appimage_file)

      # Build the AppImage
      ENV["ARCH"] = @arch == "arm64" ? "aarch64" : "x86_64"
      success = system(appimagetool, appdir_path, appimage_file, [:out, :err] => @verbose ? $stdout : File::NULL)

      # Cleanup AppDir
      FileUtils.rm_rf(appdir_path)

      if success && File.exist?(appimage_file)
        appimage_file
      else
        log "   ⚠️  AppImage creation failed. Creating .tar.gz instead."
        create_appdir_tarball
      end
    end

    def find_appimagetool
      # Check common locations
      candidates = [
        "appimagetool",
        "appimagetool-x86_64.AppImage",
        File.join(@cache_dir, "appimagetool"),
        "/usr/local/bin/appimagetool",
      ]

      candidates.find { |c| system("which #{c} >/dev/null 2>&1") }
    end

    def create_appdir_tarball
      tarball = File.join(@output_dir, "#{@name}-#{@arch}-linux.tar.gz")
      FileUtils.rm_f(tarball)

      Dir.chdir(@output_dir) do
        system("tar", "-czf", tarball, File.basename(appdir_path), [:out, :err] => File::NULL)
      end

      # Also create a simple run script
      run_script = File.join(@output_dir, "#{@name}-run.sh")
      File.write(run_script, <<~BASH)
        #!/bin/bash
        SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
        exec "$SCRIPT_DIR/#{File.basename(appdir_path)}/AppRun" "$@"
      BASH
      FileUtils.chmod(0755, run_script)

      log "   Created #{File.basename(tarball)} + #{File.basename(run_script)}"
      tarball
    end

    # --- Windows Bundle Builder ---

    def create_windows_structure
      log "📦 Creating Windows bundle structure..."
      FileUtils.rm_rf(windows_output_path)

      # Windows structure:
      # MyApp/
      #   MyApp.bat           # Launcher script
      #   ruby/               # Ruby runtime
      #     bin/              # Ruby binaries
      #     lib/              # Ruby libraries + gems
      #   app/                # User application
      #     main.rb
      #     boot.rb
      #     (assets)
      dirs = [
        windows_output_path,
        File.join(windows_output_path, "ruby", "bin"),
        File.join(windows_output_path, "ruby", "lib"),
        File.join(windows_output_path, "app"),
      ]

      dirs.each { |d| FileUtils.mkdir_p(d) }
      vlog "Created Windows bundle structure"
    end

    def copy_ruby_runtime_windows
      log "📥 Copying Ruby runtime (Windows)..."

      src = runtime_cache_path
      dst_ruby = File.join(windows_output_path, "ruby")

      # Copy Ruby binaries
      bin_src = File.join(src, "bin")
      bin_real_src = File.join(src, "bin.real")

      # Traveling Ruby on Windows has bin/ with wrapper scripts and bin.real/ with actual .exe files
      if Dir.exist?(bin_real_src)
        # Copy the real executables
        FileUtils.cp_r(bin_real_src, File.join(dst_ruby, "bin.real"))
        # Copy wrapper scripts too (for compatibility)
        Dir.glob(File.join(bin_src, "*")).each do |f|
          FileUtils.cp(f, File.join(dst_ruby, "bin", File.basename(f)))
        end
      else
        # Simpler structure - just copy bin/
        FileUtils.cp_r(bin_src, File.join(dst_ruby, "bin"))
      end

      # Copy Ruby lib (stdlib) but NOT gems
      stdlib_src = File.join(src, "lib", "ruby")
      dst_ruby_lib = File.join(dst_ruby, "lib", "ruby")
      FileUtils.mkdir_p(dst_ruby_lib)

      Dir[File.join(stdlib_src, "*")].each do |item|
        item_name = File.basename(item)
        next if item_name == "gems"  # Skip gems, we copy only required ones
        FileUtils.cp_r(item, dst_ruby_lib)
      end

      # Create empty gems structure
      FileUtils.mkdir_p(File.join(dst_ruby_lib, "gems", RUBY_ABI, "gems"))
      FileUtils.mkdir_p(File.join(dst_ruby_lib, "gems", RUBY_ABI, "specifications"))
      FileUtils.mkdir_p(File.join(dst_ruby_lib, "gems", RUBY_ABI, "extensions"))

      # Copy DLLs from lib/ root (Windows-specific shared libraries)
      Dir[File.join(src, "lib", "*.dll")].each do |dll|
        FileUtils.cp(dll, File.join(dst_ruby, "lib"))
      end

      # Copy site_ruby and vendor_ruby if they exist
      %w[site_ruby vendor_ruby].each do |dir|
        src_dir = File.join(stdlib_src, dir)
        if Dir.exist?(src_dir)
          FileUtils.cp_r(src_dir, dst_ruby_lib)
        end
      end

      vlog "Copied Ruby runtime"
    end

    def copy_gems_windows
      log "📚 Copying gems (Windows)..."

      src_gems_root = File.join(runtime_cache_path, "lib", "ruby", "gems", RUBY_ABI)
      src_gems = File.join(src_gems_root, "gems")
      src_specs = File.join(src_gems_root, "specifications")

      dst_gems_root = File.join(windows_output_path, "ruby", "lib", "ruby", "gems", RUBY_ABI)
      dst_gems = File.join(dst_gems_root, "gems")
      dst_specs = File.join(dst_gems_root, "specifications")

      FileUtils.mkdir_p(dst_gems)
      FileUtils.mkdir_p(dst_specs)

      gems_copied = []

      REQUIRED_GEMS.each do |gem_name, version, _platform|
        next if @minimal && OPTIONAL_GEMS.include?(gem_name)

        gem_dir_name = find_gem_dir(src_gems_root, gem_name, version, nil)
        if gem_dir_name
          gem_full_path = File.join(src_gems, gem_dir_name)
          FileUtils.cp_r(gem_full_path, dst_gems) if Dir.exist?(gem_full_path)
          gems_copied << gem_dir_name

          spec_file = File.join(src_specs, "#{gem_dir_name}.gemspec")
          FileUtils.cp(spec_file, dst_specs) if File.exist?(spec_file)
        else
          # Try other platform caches for pure-ruby gems
          result = find_gem_in_other_caches_cross_platform(gem_name, version)
          if result
            alt_gem_dir, alt_gems_root = result
            alt_gem_path = File.join(alt_gems_root, "gems", alt_gem_dir)
            FileUtils.cp_r(alt_gem_path, dst_gems) if Dir.exist?(alt_gem_path)
            gems_copied << alt_gem_dir

            alt_spec = File.join(alt_gems_root, "specifications", "#{alt_gem_dir}.gemspec")
            FileUtils.cp(alt_spec, dst_specs) if File.exist?(alt_spec)
          else
            vlog "⚠️  Could not find gem: #{gem_name}"
          end
        end
      end

      vlog "Copied #{gems_copied.length} gems"

      overlay_dev_sources_windows if @dev
    end

    def overlay_dev_sources_windows
      SCARPE_DEV_GEMS.each do |gem_name, paths|
        src_lib = File.join(@scarpe_root, paths[:lib])
        next unless File.directory?(src_lib)

        dst_gems = File.join(windows_output_path, "ruby", "lib", "ruby", "gems", RUBY_ABI, "gems")
        gem_dir = Dir[File.join(dst_gems, "#{gem_name}-*")].first
        next unless gem_dir

        dst_lib = File.join(gem_dir, "lib")
        FileUtils.rm_rf(dst_lib)
        FileUtils.cp_r(src_lib, gem_dir)
        vlog "Overlaid #{gem_name} with dev source"
      end
    end

    def copy_native_extensions_windows
      log "🔧 Copying native extensions (Windows)..."

      # Windows Traveling Ruby uses similar structure to Linux
      src_ext = File.join(runtime_cache_path, "lib", "ruby", "gems", RUBY_ABI, "extensions", ext_platform_dir, "#{RUBY_ABI}-static")
      dst_ext = File.join(windows_output_path, "ruby", "lib", "ruby", "gems", RUBY_ABI, "extensions", ext_platform_dir, "#{RUBY_ABI}-static")

      unless Dir.exist?(src_ext)
        # Try without -static suffix
        src_ext = File.join(runtime_cache_path, "lib", "ruby", "gems", RUBY_ABI, "extensions", ext_platform_dir, RUBY_ABI)
      end

      unless Dir.exist?(src_ext)
        vlog "No native extensions directory found"
        return
      end

      FileUtils.mkdir_p(dst_ext)

      NATIVE_EXTENSION_GEMS.each do |gem|
        next if @minimal && OPTIONAL_GEMS.include?(gem)

        gem_ext = Dir[File.join(src_ext, "#{gem}-*")].first
        if gem_ext
          FileUtils.cp_r(gem_ext, dst_ext)
          vlog "Copied #{gem} native extension"
        end
      end
    end

    def copy_webview_extension_windows
      log "🖼️  Copying webview extension (Windows)..."

      ext_dir = File.join(windows_output_path, "ruby", "lib", "ruby", "gems", RUBY_ABI, "gems", "webview_ruby-0.1.2", "ext", ext_platform_dir)
      FileUtils.mkdir_p(ext_dir)

      # Check for pre-built extension in cache
      cached_ext = File.join(@cache_dir, "webview-ext", "webview-#{platform_string}.dll")

      if File.exist?(cached_ext)
        FileUtils.cp(cached_ext, File.join(ext_dir, "webview.dll"))
        vlog "Copied pre-built webview extension"
      elsif @skip_webview_check
        warn "⚠️  Skipping webview extension (--skip-webview-check) - app will NOT run!"
        vlog "Creating placeholder for webview extension"
        File.write(File.join(ext_dir, "webview.dll"), "# PLACEHOLDER - compile and replace this file\n")
      else
        raise <<~ERROR
          Missing pre-built webview extension for #{platform_string}.

          The webview native extension must be compiled on a Windows system with
          Visual Studio or MinGW and the WebView2 SDK installed.

          To build manually with MinGW:
            g++ -shared -static-libgcc -static-libstdc++ \\
              -DWEBVIEW_EDGE \\
              -o webview.dll \\
              webview.cpp \\
              -lwebview2loader -lole32 -lshell32 -lshlwapi -luser32

          Or with Visual Studio:
            cl /LD /DWEBVIEW_EDGE webview.cpp \\
              WebView2Loader.lib ole32.lib shell32.lib shlwapi.lib user32.lib

          Place the compiled .dll in: #{File.dirname(cached_ext)}/

          Tip: Use --skip-webview-check to build anyway (for testing structure).
        ERROR
      end
    end

    def copy_user_app_windows
      log "📄 Copying user app..."

      app_dir = File.join(windows_output_path, "app")
      FileUtils.cp(@app_file, File.join(app_dir, "main.rb"))

      # Copy any assets from the same directory
      app_source_dir = File.dirname(@app_file)
      %w[*.png *.jpg *.jpeg *.gif *.svg *.ico *.ttf *.otf *.woff *.woff2 *.css *.js *.html].each do |pattern|
        Dir[File.join(app_source_dir, pattern)].each do |asset|
          FileUtils.cp(asset, app_dir)
        end
      end

      # Copy well-known asset directories
      %w[images assets fonts sounds].each do |subdir|
        src_subdir = File.join(app_source_dir, subdir)
        if Dir.exist?(src_subdir)
          FileUtils.cp_r(src_subdir, File.join(app_dir, subdir))
        end
      end

      vlog "Copied user application"
    end

    def write_boot_script_windows
      boot_rb = File.join(windows_output_path, "app", "boot.rb")

      File.write(boot_rb, <<~RUBY)
        # Boot script for packaged Scarpe app (Windows)
        # Auto-generated by scarpe package

        # Relax dependency checking for packaged apps
        module Gem
          class Specification
            alias_method :_packaged_activate_deps, :activate_dependencies
            def activate_dependencies
              _packaged_activate_deps
            rescue Gem::MissingSpecError
              # Optional dependency not present in bundle
            end
          end
        end

        # Suppress changelog warning
        ENV["SCARPE_SILENCE_CHANGELOG"] = "1"
        ENV["SCARPE_DISPLAY"] = "wv_local"

        require "scarpe"
        require "scarpe/wv"

        # Load and run the app
        load File.join(__dir__, "main.rb")
      RUBY

      vlog "Wrote boot.rb"
    end

    def write_windows_launcher
      # Write a batch file launcher
      batch_path = File.join(windows_output_path, "#{@name}.bat")

      # Note: Using %~dp0 to get the directory containing the batch file
      File.write(batch_path, <<~BATCH)
        @echo off
        REM #{@name} - Packaged with Scarpe
        REM Auto-generated launcher script

        setlocal EnableDelayedExpansion

        REM Get the directory containing this batch file
        set "APPDIR=%~dp0"
        set "APPDIR=%APPDIR:~0,-1%"

        REM Set up Ruby environment
        set "RUBY_ROOT=%APPDIR%\\ruby"
        set "GEM_HOME=%RUBY_ROOT%\\lib\\ruby\\gems\\#{RUBY_ABI}"
        set "GEM_PATH=%GEM_HOME%"
        set "PATH=%RUBY_ROOT%\\bin;%RUBY_ROOT%\\bin.real;%PATH%"

        REM Check for WebView2 Runtime
        REM WebView2 is required for the GUI - pre-installed on Windows 11
        reg query "HKEY_LOCAL_MACHINE\\SOFTWARE\\WOW6432Node\\Microsoft\\EdgeUpdate\\Clients\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" >nul 2>&1
        if errorlevel 1 (
            reg query "HKEY_CURRENT_USER\\Software\\Microsoft\\EdgeUpdate\\Clients\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" >nul 2>&1
            if errorlevel 1 (
                echo.
                echo ERROR: Microsoft WebView2 Runtime is required but not installed.
                echo.
                echo Download it from:
                echo   https://developer.microsoft.com/en-us/microsoft-edge/webview2/
                echo.
                echo Or install via winget:
                echo   winget install Microsoft.EdgeWebView2Runtime
                echo.
                pause
                exit /b 1
            )
        )

        REM Find the Ruby executable
        if exist "%RUBY_ROOT%\\bin.real\\ruby.exe" (
            set "RUBY_EXE=%RUBY_ROOT%\\bin.real\\ruby.exe"
        ) else (
            set "RUBY_EXE=%RUBY_ROOT%\\bin\\ruby.exe"
        )

        REM Change to app directory and run
        cd /d "%APPDIR%\\app"
        "%RUBY_EXE%" boot.rb
      BATCH

      vlog "Wrote #{@name}.bat launcher"
    end

    def copy_icon_windows
      return unless @icon && File.exist?(@icon)

      # For Windows, we just copy the icon to the app directory
      # A proper .exe launcher with embedded icon would require more work
      icon_dest = File.join(windows_output_path, "app", "icon" + File.extname(@icon))
      FileUtils.cp(@icon, icon_dest)
      vlog "Copied application icon"
    end

    def strip_unnecessary_files_windows
      log "🗑️  Stripping unnecessary files..."

      gems_dir = File.join(windows_output_path, "ruby", "lib", "ruby", "gems", RUBY_ABI, "gems")
      ruby_dir = File.join(windows_output_path, "ruby", "lib", "ruby")

      # Remove development files (be careful not to delete code files like changelog.rb!)
      patterns = %w[
        **/test/**
        **/spec/**
        **/tests/**
        **/CHANGELOG.md
        **/README.md
        **/LICENSE
        **/LICENSE.txt
        **/Rakefile
        **/Gemfile*
        **/.git*
        **/.rubocop*
      ]

      patterns.each do |pattern|
        Dir.glob(File.join(gems_dir, pattern)).each do |f|
          FileUtils.rm_rf(f)
        end
      end

      # Remove C source files (not needed on Windows either)
      %w[*.c *.h *.cpp *.cxx *.o Makefile mkmf.log].each do |pattern|
        Dir.glob(File.join(gems_dir, "**", pattern)).each do |f|
          File.delete(f) if File.file?(f)
        end
      end

      # Additional minimal stripping
      strip_minimal_windows(gems_dir, ruby_dir) if @minimal

      vlog "Stripped unnecessary files"
    end

    def strip_minimal_windows(gems_dir, ruby_dir)
      # Similar to regular strip_minimal but adapted for Windows paths
      OPTIONAL_GEMS.each do |gem_name|
        Dir.glob(File.join(gems_dir, "#{gem_name}-*")).each do |d|
          FileUtils.rm_rf(d)
          vlog "  Removed gem: #{File.basename(d)}"
        end
        specs_dir = File.join(File.dirname(gems_dir), "specifications")
        Dir.glob(File.join(specs_dir, "#{gem_name}-*")).each do |s|
          File.delete(s) if File.file?(s)
        end
      end

      # Remove SSL DLLs in minimal mode
      Dir.glob(File.join(windows_output_path, "ruby", "lib", "libcrypto*")).each do |f|
        File.delete(f)
      end
      Dir.glob(File.join(windows_output_path, "ruby", "lib", "libssl*")).each do |f|
        File.delete(f)
      end

      # Remove optional stdlib modules
      stdlib_dir = File.join(ruby_dir, RUBY_ABI)
      MINIMAL_STRIP_STDLIB.each do |lib|
        path = File.join(stdlib_dir, lib)
        FileUtils.rm_rf(path) if Dir.exist?(path)
        rb_file = File.join(stdlib_dir, "#{lib}.rb")
        File.delete(rb_file) if File.exist?(rb_file)
      end
    end

    def create_windows_zip
      log "📦 Creating distribution archive..."

      # Create a .zip file for easy distribution
      zip_path = File.join(@output_dir, "#{@name}-#{@arch}-windows.zip")
      FileUtils.rm_f(zip_path)

      # Use PowerShell's Compress-Archive on Windows, or zip on Unix
      if Gem.win_platform?
        # On Windows
        ps_command = "Compress-Archive -Path '#{windows_output_path}' -DestinationPath '#{zip_path}' -Force"
        system("powershell", "-Command", ps_command, [:out, :err] => @verbose ? $stdout : File::NULL)
      else
        # On macOS/Linux (cross-building)
        Dir.chdir(@output_dir) do
          system("zip", "-r", "-q", zip_path, File.basename(windows_output_path), [:out, :err] => @verbose ? $stdout : File::NULL)
        end
      end

      if File.exist?(zip_path)
        zip_size = (File.size(zip_path) / 1024.0 / 1024.0).round(1)
        log "   ✅ Created #{File.basename(zip_path)} (#{zip_size}MB)"
      end

      windows_output_path
    end

    # --- Class-level entry point for CLI ---

    def self.run(args)
      options = parse_args(args)

      if options[:help] || options[:app_file].nil?
        print_usage
        exit(options[:help] ? 0 : 1)
      end

      packager = new(
        options[:app_file],
        name: options[:name],
        icon: options[:icon],
        arch: options[:arch],
        output_dir: options[:output_dir],
        verbose: options[:verbose],
        dev: options[:dev],
        sign: options[:sign],
        dmg: options[:dmg],
        universal: options[:universal],
        minimal: options[:minimal],
        target_os: options[:target_os],
        skip_webview_check: options[:skip_webview_check],
      )
      packager.build!
    rescue => e
      $stderr.puts "❌ Packaging failed: #{e.message}"
      $stderr.puts e.backtrace.first(5).map { |l| "   #{l}" }.join("\n") if options&.dig(:verbose)
      exit 1
    end

    def self.parse_args(args)
      options = {}
      remaining = []

      i = 0
      while i < args.length
        case args[i]
        when "--name", "-n"
          options[:name] = args[i + 1]
          i += 2
        when "--icon", "-i"
          options[:icon] = args[i + 1]
          i += 2
        when "--arch", "-a"
          options[:arch] = args[i + 1]
          i += 2
        when "--output", "-o"
          options[:output_dir] = args[i + 1]
          i += 2
        when "--verbose", "-V"
          options[:verbose] = true
          i += 1
        when "--dev"
          options[:dev] = true
          i += 1
        when "--sign", "-s"
          options[:sign] = true
          i += 1
        when "--dmg"
          options[:dmg] = true
          i += 1
        when "--universal", "-u"
          options[:universal] = true
          i += 1
        when "--minimal", "-m"
          options[:minimal] = true
          i += 1
        when "--target", "-t"
          options[:target_os] = args[i + 1]
          i += 2
        when "--linux"
          options[:target_os] = "linux"
          i += 1
        when "--linux-musl"
          options[:target_os] = "linux-musl"
          i += 1
        when "--windows"
          options[:target_os] = "windows"
          i += 1
        when "--skip-webview-check"
          options[:skip_webview_check] = true
          i += 1
        when "--help", "-h"
          options[:help] = true
          i += 1
        else
          remaining << args[i]
          i += 1
        end
      end

      options[:app_file] = remaining.first
      options
    end

    def self.print_usage
      puts <<~USAGE
        Usage: scarpe package <app.rb> [OPTIONS]

        Package a Shoes/Scarpe application as a standalone executable.

        Output formats:
          macOS (default):  .app bundle (optionally as .dmg disk image)
          Linux:            AppImage or .tar.gz bundle
          Windows:          Folder with .bat launcher (+ .zip for distribution)

        Options:
          -n, --name NAME       Application name (default: derived from filename)
          -i, --icon FILE       Application icon (.icns/.png for macOS, .png/.svg for Linux)
          -a, --arch ARCH       Target architecture: x86_64 or arm64 (default: current)
          -t, --target OS       Target OS: macos, linux, linux-musl, windows (default: current)
              --linux           Shortcut for --target linux
              --linux-musl      Shortcut for --target linux-musl (Alpine/Docker)
              --windows         Shortcut for --target windows
          -o, --output DIR      Output directory (default: current directory)
          -V, --verbose         Show detailed progress
              --dev             Use local development Scarpe source (not published gems)
          -m, --minimal         Strip optional gems & SSL for smallest build
                                Removes: nokogiri, sqlite3, fastimage, SSL/crypto
                                Apps using download/Image auto-size won't work
              --skip-webview-check  Skip webview extension check (for testing builds)

        macOS-specific options:
          -s, --sign            Ad-hoc code sign the .app (reduces Gatekeeper warnings)
              --dmg             Also create a .dmg disk image for distribution
          -u, --universal       Build universal binary (x86_64 + arm64)

          -h, --help            Show this help

        Examples:
          # macOS
          scarpe package myapp.rb
          scarpe package myapp.rb --name "My App" --icon icon.png --sign
          scarpe package myapp.rb --minimal --sign --dmg
          scarpe package myapp.rb --universal --sign --dmg

          # Linux
          scarpe package myapp.rb --linux
          scarpe package myapp.rb --linux --minimal
          scarpe package myapp.rb --target linux-musl --arch arm64

          # Windows (cross-build from macOS/Linux)
          scarpe package myapp.rb --windows
          scarpe package myapp.rb --windows --minimal
          scarpe package myapp.rb --windows --arch arm64  # Windows ARM

        The packaged app requires no Ruby installation to run.
        First run downloads and caches the Ruby runtime (~58MB).

        Linux packaging notes:
          - Requires WebKitGTK on the target system (libwebkit2gtk-4.1-0)
          - Requires pre-built webview extension (compile with --verbose for instructions)
          - AppImage creation requires appimagetool (falls back to .tar.gz if not found)

        Windows packaging notes:
          - Requires WebView2 Runtime on the target system (pre-installed on Windows 11)
          - Windows 10 users must install WebView2: https://go.microsoft.com/fwlink/p/?LinkId=2124703
          - Requires pre-built webview.dll extension (compile with --verbose for instructions)
          - Cross-build support: build Windows packages from macOS/Linux
          - Creates MyApp/ folder + MyApp.zip for distribution
      USAGE
    end
  end
end
