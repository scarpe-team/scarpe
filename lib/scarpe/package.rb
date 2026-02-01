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

    # Platform directory names vary between extensions and stdlib in Traveling Ruby:
    #   Extensions: x86_64-darwin-22 (with hyphen)
    #   Stdlib:     x86_64-darwin22  (no hyphen)
    EXT_PLATFORM = { "x86_64" => "x86_64-darwin-22", "arm64" => "arm64-darwin-22" }.freeze
    RUBY_PLATFORM_DIR = { "x86_64" => "x86_64-darwin22", "arm64" => "arm64-darwin22" }.freeze

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

    def initialize(app_file, name: nil, icon: nil, arch: nil, output_dir: nil, verbose: false, dev: false)
      @app_file = File.expand_path(app_file)
      raise "App file not found: #{@app_file}" unless File.exist?(@app_file)
      raise "App file must be a .rb file: #{@app_file}" unless @app_file.end_with?(".rb")

      @name = sanitize_name(name || File.basename(app_file, ".rb"))
      @icon = icon ? File.expand_path(icon) : nil
      @arch = ARCH_MAP[arch || detect_arch] || raise("Unsupported architecture: #{arch}")
      @output_dir = output_dir ? File.expand_path(output_dir) : Dir.pwd
      @verbose = verbose
      @dev = dev

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
      log "   Output: #{app_path}"
      log ""

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

      size = `du -sh "#{app_path}" 2>/dev/null`.strip.split("\t").first || "unknown"
      log ""
      log "✅ Created #{File.basename(app_path)} (#{size})"
      log ""
      log "   To run:  open #{app_path}"
      log "   Or:      #{app_path}/Contents/MacOS/scarpe-launcher"
      log ""
      log "   ⚠️  Unsigned app — right-click → Open to bypass Gatekeeper."

      app_path
    end

    def app_path
      File.join(@output_dir, "#{@name}.app")
    end

    private

    def log(msg)
      puts msg
    end

    def vlog(msg)
      puts "  [debug] #{msg}" if @verbose
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

    def platform_string
      "macos-#{@arch}"
    end

    def ext_platform_dir
      EXT_PLATFORM[@arch]
    end

    def ruby_platform_dir
      RUBY_PLATFORM_DIR[@arch]
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
        if gem_dir_name
          src_dir = File.join(src_gems, "gems", gem_dir_name)
          FileUtils.cp_r(src_dir, File.join(dst_gems, "gems", gem_dir_name))

          # Copy gemspec
          spec_file = "#{gem_dir_name}.gemspec"
          src_spec = File.join(src_gems, "specifications", spec_file)
          if File.exist?(src_spec)
            FileUtils.cp(src_spec, File.join(dst_gems, "specifications", spec_file))
          else
            vlog "⚠️  Gemspec not found: #{spec_file}"
          end

          vlog "  ✅ #{gem_dir_name}"
        else
          log "   ⚠️  Gem not found in cache: #{gem_name}"
        end
      end

      # In --dev mode, overlay local Scarpe source on top of published gems
      overlay_dev_sources if @dev
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
      log "🔧 Copying webview_ruby native extension..."

      # Find webview_ruby's native extension on the system
      webview_bundle = find_webview_bundle
      unless webview_bundle
        log "   ⚠️  webview_ruby native extension not found!"
        log "   The packaged app may not work. Run: gem install webview_ruby"
        return
      end

      # Determine destination based on source architecture
      dst_gems = File.join(app_path, "Contents/Resources/runtime/gems/gems")
      webview_ext_dir = Dir.glob(File.join(dst_gems, "webview_ruby-*/ext")).first

      if webview_ext_dir
        target_dir = File.join(webview_ext_dir, "#{@arch}-darwin")
        FileUtils.mkdir_p(target_dir)
        FileUtils.cp(webview_bundle, File.join(target_dir, "libwebview-ext.bundle"))
        vlog "  ✅ Copied #{File.basename(webview_bundle)} to #{target_dir}"
      else
        log "   ⚠️  webview_ruby gem directory not found in bundle"
      end
    end

    def find_webview_bundle
      # Search common locations for the webview_ruby native extension
      search_paths = [
        # mise/asdf
        File.join(Dir.home, ".local/share/mise/installs/ruby/*/lib/ruby/gems/*/gems/webview_ruby-*/ext/*/libwebview-ext.bundle"),
        # rbenv
        File.join(Dir.home, ".rbenv/versions/*/lib/ruby/gems/*/gems/webview_ruby-*/ext/*/libwebview-ext.bundle"),
        # System Ruby
        "/Library/Ruby/Gems/*/gems/webview_ruby-*/ext/*/libwebview-ext.bundle",
        # Homebrew Ruby
        "/usr/local/lib/ruby/gems/*/gems/webview_ruby-*/ext/*/libwebview-ext.bundle",
        "/opt/homebrew/lib/ruby/gems/*/gems/webview_ruby-*/ext/*/libwebview-ext.bundle",
        # Traveling Ruby cache (from previous build)
        File.join(runtime_cache_path, "lib/ruby/gems/*/gems/webview_ruby-*/ext/*/libwebview-ext.bundle"),
      ]

      search_paths.each do |pattern|
        matches = Dir.glob(pattern)
        # Prefer the architecture-matching one
        arch_match = matches.find { |m| m.include?(@arch) }
        return arch_match if arch_match
        return matches.first unless matches.empty?
      end

      nil
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

      # Remove test/spec/doc directories
      removable_dirs = %w[test spec examples docs doc .git spikes experiments benchmark features]
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

      # Remove README/CHANGELOG/LICENSE (space savings, not needed at runtime)
      %w[README* CHANGELOG* CHANGES* HISTORY* LICENSE* COPYING* NEWS* TODO*].each do |pattern|
        Dir.glob(File.join(gems_dir, "*", pattern)).each do |f|
          File.delete(f) if File.file?(f)
        end
      end

      # Strip dSYM directories from native extensions (debug symbols)
      Dir.glob(File.join(app_path, "**", "*.dSYM")).each do |dsym|
        FileUtils.rm_rf(dsym)
      end

      final_size = `du -sh "#{app_path}" 2>/dev/null`.strip.split("\t").first
      vlog "  Stripped to #{final_size}"
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

        Package a Shoes/Scarpe application as a standalone macOS .app bundle.

        Options:
          -n, --name NAME       Application name (default: derived from filename)
          -i, --icon FILE       Application icon (.icns or .png)
          -a, --arch ARCH       Target architecture: x86_64 or arm64 (default: current)
          -o, --output DIR      Output directory (default: current directory)
          -V, --verbose         Show detailed progress
              --dev             Use local development Scarpe source (not published gems)
          -h, --help            Show this help

        Examples:
          scarpe package myapp.rb
          scarpe package myapp.rb --name "My App" --icon icon.png
          scarpe package myapp.rb --arch arm64 --output ~/Desktop

        The packaged .app requires no Ruby installation to run.
        First run downloads and caches the Ruby runtime (~58MB).
      USAGE
    end
  end
end
