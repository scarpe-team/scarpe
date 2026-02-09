# frozen_string_literal: true

require "fileutils"
require "tmpdir"

module Scarpe
  # Manage webview native extensions for cross-platform packaging.
  #
  # Usage:
  #   scarpe extension status          # Show cached extensions
  #   scarpe extension build linux     # Build Linux extensions via Docker
  #   scarpe extension build all       # Build all Linux extensions
  #
  class Extension
    CACHE_DIR = File.expand_path("~/.scarpe/packager-cache/webview-ext")
    WEBVIEW_GEM_VERSION = "0.1.2"

    # Extension file names by platform
    EXTENSION_FILES = {
      "macos-x86_64"      => "libwebview-ext-x86_64.bundle",
      "macos-arm64"       => "libwebview-ext-arm64.bundle",
      "macos-universal"   => "libwebview-ext-universal.bundle",
      "linux-x86_64"      => "libwebview-ext-linux-x86_64.so",
      "linux-arm64"       => "libwebview-ext-linux-arm64.so",
      "linux-musl-x86_64" => "libwebview-ext-linux-musl-x86_64.so",
      "linux-musl-arm64"  => "libwebview-ext-linux-musl-arm64.so",
      "windows-x86_64"    => "webview-x86_64.dll",
      "windows-arm64"     => "webview-arm64.dll",
    }.freeze

    # Platforms that can be built via Docker from macOS
    DOCKER_BUILDABLE = %w[
      linux-x86_64
      linux-arm64
      linux-musl-x86_64
      linux-musl-arm64
    ].freeze

    def initialize(verbose: false)
      @verbose = verbose
      FileUtils.mkdir_p(CACHE_DIR)
    end

    def log(msg)
      puts msg if @verbose
    end

    # Show status of all cached extensions
    def status
      puts "📦 Webview Extension Cache"
      puts "   Location: #{CACHE_DIR}"
      puts ""
      
      cached_files = Dir[File.join(CACHE_DIR, "*")].map { |f| File.basename(f) }
      
      puts "   Platform                Status     Size"
      puts "   " + "-" * 50
      
      EXTENSION_FILES.each do |platform, filename|
        path = File.join(CACHE_DIR, filename)
        if File.exist?(path)
          size = (File.size(path) / 1024.0).round(1)
          puts "   #{platform.ljust(20)} ✅ Cached   #{size}KB"
        else
          puts "   #{platform.ljust(20)} ❌ Missing"
        end
      end
      
      puts ""
      puts "📋 Build Commands:"
      puts "   scarpe extension build linux          # x86_64 glibc + musl (fast)"
      puts "   scarpe extension build linux-arm64    # ARM64 glibc + musl (slow, uses QEMU)"
      puts "   scarpe extension build all            # All Linux variants"
      puts ""
      puts "   Note: macOS extensions are built automatically during packaging."
      puts "   Windows extensions require a Windows machine with WebView2 SDK."
    end

    # Build extensions via Docker
    def build(target)
      case target
      when "linux", "linux-x86_64"
        build_linux_x86_64
      when "linux-arm64"
        build_linux_arm64
      when "linux-musl", "linux-musl-x86_64"
        build_linux_musl_x86_64
      when "linux-musl-arm64"
        build_linux_musl_arm64
      when "all"
        build_all_linux
      else
        $stderr.puts "Unknown target: #{target}"
        $stderr.puts "Valid targets: linux, linux-arm64, linux-musl, linux-musl-arm64, all"
        exit 1
      end
    end

    # Build all Linux variants
    def build_all_linux
      puts "🔨 Building all Linux webview extensions..."
      puts ""
      
      # Fast builds first
      build_linux_x86_64
      build_linux_musl_x86_64
      
      puts ""
      puts "⚠️  ARM64 builds use QEMU emulation and are SLOW (10-15 minutes each)"
      print "Continue with ARM64 builds? [y/N] "
      response = $stdin.gets.strip.downcase
      
      if response == "y" || response == "yes"
        build_linux_arm64
        build_linux_musl_arm64
      else
        puts "Skipping ARM64 builds."
      end
      
      puts ""
      status
    end

    private

    def check_docker
      unless system("docker", "info", [:out, :err] => File::NULL)
        $stderr.puts "❌ Docker is not running or not installed."
        $stderr.puts "   Please start Docker Desktop and try again."
        exit 1
      end
    end

    def download_webview_source
      @work_dir = Dir.mktmpdir("webview-build")
      puts "📥 Downloading webview_ruby source..."
      
      gem_url = "https://rubygems.org/downloads/webview_ruby-#{WEBVIEW_GEM_VERSION}.gem"
      gem_path = File.join(@work_dir, "webview_ruby.gem")
      
      # Download gem
      require "open-uri"
      URI.open(gem_url) do |remote|
        File.open(gem_path, "wb") { |f| f.write(remote.read) }
      end
      
      # Extract gem
      Dir.chdir(@work_dir) do
        system("tar", "xf", "webview_ruby.gem", [:out, :err] => File::NULL)
        system("tar", "xf", "data.tar.gz", [:out, :err] => File::NULL)
      end
      
      ext_dir = File.join(@work_dir, "ext", "webview")
      unless Dir.exist?(ext_dir)
        $stderr.puts "❌ Failed to extract webview source"
        exit 1
      end
      
      ext_dir
    end

    def cleanup_work_dir
      FileUtils.rm_rf(@work_dir) if @work_dir && Dir.exist?(@work_dir)
    end

    def build_linux_x86_64
      check_docker
      ext_dir = download_webview_source
      output_file = "libwebview-ext-linux-x86_64.so"
      
      puts "🔨 Building Linux (glibc) extension for x86_64..."
      
      success = system(
        "docker", "run", "--rm", "--platform", "linux/amd64",
        "-v", "#{ext_dir}:/work",
        "ubuntu:22.04", "bash", "-c", <<~CMD
          apt-get update -qq >/dev/null 2>&1
          apt-get install -qq -y build-essential libgtk-3-dev libwebkit2gtk-4.1-dev pkg-config >/dev/null 2>&1
          cd /work
          c++ -shared -fPIC -O2 \
            $(pkg-config --cflags gtk+-3.0 webkit2gtk-4.1) \
            -DWEBVIEW_GTK \
            -o #{output_file} \
            webview.cpp \
            $(pkg-config --libs gtk+-3.0 webkit2gtk-4.1) 2>&1
        CMD
      )
      
      if success && File.exist?(File.join(ext_dir, output_file))
        FileUtils.cp(File.join(ext_dir, output_file), CACHE_DIR)
        size = (File.size(File.join(CACHE_DIR, output_file)) / 1024.0).round(1)
        puts "   ✅ Created #{output_file} (#{size}KB)"
      else
        $stderr.puts "   ❌ Build failed for #{output_file}"
      end
      
      cleanup_work_dir
    end

    def build_linux_musl_x86_64
      check_docker
      ext_dir = download_webview_source
      output_file = "libwebview-ext-linux-musl-x86_64.so"
      
      puts "🔨 Building Linux (musl/Alpine) extension for x86_64..."
      
      success = system(
        "docker", "run", "--rm", "--platform", "linux/amd64",
        "-v", "#{ext_dir}:/work",
        "alpine:3.19", "sh", "-c", <<~CMD
          apk add --no-cache build-base gtk+3.0-dev webkit2gtk-4.1-dev pkgconf >/dev/null 2>&1
          cd /work
          c++ -shared -fPIC -O2 \
            $(pkg-config --cflags gtk+-3.0 webkit2gtk-4.1) \
            -DWEBVIEW_GTK \
            -o #{output_file} \
            webview.cpp \
            $(pkg-config --libs gtk+-3.0 webkit2gtk-4.1) 2>&1
        CMD
      )
      
      if success && File.exist?(File.join(ext_dir, output_file))
        FileUtils.cp(File.join(ext_dir, output_file), CACHE_DIR)
        size = (File.size(File.join(CACHE_DIR, output_file)) / 1024.0).round(1)
        puts "   ✅ Created #{output_file} (#{size}KB)"
      else
        $stderr.puts "   ❌ Build failed for #{output_file}"
      end
      
      cleanup_work_dir
    end

    def build_linux_arm64
      check_docker
      ext_dir = download_webview_source
      output_file = "libwebview-ext-linux-arm64.so"
      
      puts "🔨 Building Linux (glibc) extension for ARM64..."
      puts "   ⚠️  This uses QEMU emulation and will take 10-15 minutes..."
      
      success = system(
        "docker", "run", "--rm", "--platform", "linux/arm64",
        "-v", "#{ext_dir}:/work",
        "ubuntu:22.04", "bash", "-c", <<~CMD
          apt-get update -qq >/dev/null 2>&1
          apt-get install -qq -y build-essential libgtk-3-dev libwebkit2gtk-4.1-dev pkg-config >/dev/null 2>&1
          cd /work
          c++ -shared -fPIC -O2 \
            $(pkg-config --cflags gtk+-3.0 webkit2gtk-4.1) \
            -DWEBVIEW_GTK \
            -o #{output_file} \
            webview.cpp \
            $(pkg-config --libs gtk+-3.0 webkit2gtk-4.1) 2>&1
        CMD
      )
      
      if success && File.exist?(File.join(ext_dir, output_file))
        FileUtils.cp(File.join(ext_dir, output_file), CACHE_DIR)
        size = (File.size(File.join(CACHE_DIR, output_file)) / 1024.0).round(1)
        puts "   ✅ Created #{output_file} (#{size}KB)"
      else
        $stderr.puts "   ❌ Build failed for #{output_file}"
      end
      
      cleanup_work_dir
    end

    def build_linux_musl_arm64
      check_docker
      ext_dir = download_webview_source
      output_file = "libwebview-ext-linux-musl-arm64.so"
      
      puts "🔨 Building Linux (musl/Alpine) extension for ARM64..."
      puts "   ⚠️  This uses QEMU emulation and will take 10-15 minutes..."
      
      success = system(
        "docker", "run", "--rm", "--platform", "linux/arm64",
        "-v", "#{ext_dir}:/work",
        "alpine:3.19", "sh", "-c", <<~CMD
          apk add --no-cache build-base gtk+3.0-dev webkit2gtk-4.1-dev pkgconf >/dev/null 2>&1
          cd /work
          c++ -shared -fPIC -O2 \
            $(pkg-config --cflags gtk+-3.0 webkit2gtk-4.1) \
            -DWEBVIEW_GTK \
            -o #{output_file} \
            webview.cpp \
            $(pkg-config --libs gtk+-3.0 webkit2gtk-4.1) 2>&1
        CMD
      )
      
      if success && File.exist?(File.join(ext_dir, output_file))
        FileUtils.cp(File.join(ext_dir, output_file), CACHE_DIR)
        size = (File.size(File.join(CACHE_DIR, output_file)) / 1024.0).round(1)
        puts "   ✅ Created #{output_file} (#{size}KB)"
      else
        $stderr.puts "   ❌ Build failed for #{output_file}"
      end
      
      cleanup_work_dir
    end

    # --- Class-level entry point for CLI ---

    def self.run(args)
      if args.empty? || args[0] == "status" || args[0] == "list"
        new(verbose: true).status
      elsif args[0] == "build"
        target = args[1] || "linux"
        new(verbose: true).build(target)
      elsif args[0] == "help" || args[0] == "-h" || args[0] == "--help"
        print_usage
      else
        $stderr.puts "Unknown command: #{args[0]}"
        print_usage
        exit 1
      end
    end

    def self.print_usage
      puts <<~USAGE
        Usage: scarpe extension [COMMAND] [OPTIONS]

        Manage webview native extensions for cross-platform packaging.

        Commands:
          status              Show status of cached extensions (default)
          list                Alias for status
          build [TARGET]      Build extensions via Docker

        Build targets:
          linux               Build x86_64 glibc + musl (fast, ~60 seconds)
          linux-arm64         Build ARM64 glibc (slow, ~15 minutes via QEMU)
          linux-musl-arm64    Build ARM64 musl (slow, ~15 minutes via QEMU)
          all                 Build all Linux variants (prompts for ARM64)

        Examples:
          scarpe extension                    # Show status
          scarpe extension build linux        # Build x86_64 Linux extensions
          scarpe extension build all          # Build all Linux extensions

        Notes:
          - Docker is required for building Linux extensions
          - ARM64 builds use QEMU emulation and are significantly slower
          - macOS extensions are built automatically during packaging
          - Windows extensions require a Windows machine with WebView2 SDK

        Cache location: ~/.scarpe/packager-cache/webview-ext/
      USAGE
    end
  end
end
