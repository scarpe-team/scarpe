# frozen_string_literal: true

require "erb"
require "open3"
require "shellwords"
require_relative "bytecode"

module Scarpe
  class Package
    # `scarpe package --native`: a macOS .app that draws with the Rust display service
    # (native/DESIGN.md section 11, docs/native_packaging.md). Next to the webview build it leaves
    # out WebKit, the gems and the webview extension, and carries instead:
    #
    #   Contents/MacOS/scarpe-launcher     bash: Traveling Ruby's environment, then exec Ruby on boot.rb
    #   Contents/MacOS/scarpe-native       the release Rust binary, stripped and signed
    #   Contents/Resources/boot.rb         installs the bytecode loader, requires scarpe, runs the app
    #   Contents/Resources/scarpe/         lib, lacci/lib and scarpe-components/lib, from source, and the manual
    #   Contents/Resources/bytecode/       all of that, and the app, precompiled (Bytecode)
    #   Contents/Resources/app/            the app and its assets
    #   Contents/Resources/runtime/ruby/   Traveling Ruby, stripped as for any build
    #
    # Scarpe comes straight from the source tree this packager lives in, never from an installed
    # gem, so what you run in development is what ships.
    class Native < Package
      BINARY = "scarpe-native"
      INSTALL_DIR = "/Applications"
      TEMPLATES = File.expand_path("../../../templates/package", __dir__)

      # Source directories, copied to Contents/Resources/scarpe/ under the same names.
      SOURCES = %w[lib lacci/lib scarpe-components/lib].freeze
      # The webview display service and the packager itself stay behind (paths under lib/).
      LEAVE_OUT = %w[
        scarpe/wv scarpe/wv.rb scarpe/wv_local.rb scarpe/wv_relay.rb scarpe/assets.rb
        scarpe/package.rb scarpe/package/native.rb scarpe/extension.rb
      ].freeze
      # Shipped beside the sources, at the same paths: Lacci reads its release name from
      # CHANGELOG.md, and Shoes.show_manual draws its window from docs/static/manual.md (ledger K7).
      SOURCE_FILES = %w[CHANGELOG.md LICENSE.txt docs/static/manual.md].freeze
      # Pure-Ruby gems Lacci requires when an app asks for them, copied from the packager's own
      # Ruby to Contents/Resources/scarpe/gems/NAME/lib: FastImage reads image sizes (Image#size,
      # imagesize), and needs base64, which Ruby 3.4 moved out of the standard library. --minimal
      # leaves them out along with OpenSSL, which FastImage requires too.
      VENDORED_GEMS = %w[fastimage base64].freeze
      # strip_unnecessary_files deletes these libraries, and Ruby warns at every start if it looks.
      RUBY_FLAGS = %w[--disable-did_you_mean --disable-error_highlight --disable-syntax_suggest].freeze
      # --minimal strips libraries the native shim needs for its first image download: net/http and
      # resolv fetch images, digest names the image cache (normalize.rb requires them then, not at
      # boot). They come back from the cached runtime (paths under the stdlib; %{platform} is the
      # stdlib's native-extension directory). Without OpenSSL, https stays out.
      MINIMAL_KEEPS = %w[net resolv.rb %{platform}/digest.bundle %{platform}/digest].freeze

      def initialize(app_file, install_dir: INSTALL_DIR, bytecode: true, **options)
        super(app_file, **options)
        raise "Native packaging makes macOS apps for now (not #{@target_os})" unless @target_os == "macos"
        raise "Native packaging builds one architecture (#{@arch}); --universal is not supported yet" if @universal

        # A name given with --name is what Finder, the Dock and the disk image show, so it stays as
        # written ("ZARKING (Rust)", "For Noah") less what a file name cannot hold. A name made from
        # the file name stays CamelCase, as for every build.
        if (given = given_name(options[:name]))
          @name = given
          @bundle_id = "com.scarpe.#{given.downcase.gsub(/[^a-z0-9]/, "").then { |id| id.empty? ? "app" : id }}"
        end

        @scarpe_root ||= find_scarpe_root || raise("Cannot find the Scarpe source (lib/scarpe and lacci/lib)")
        @install_dir = install_dir
        @bytecode = bytecode
        @sign = true # Apple silicon runs nothing unsigned, and stripping the binary drops its signature.
      end

      def build_macos!
        ensure_runtime_cached
        create_bundle_structure
        copy_ruby_runtime
        copy_scarpe_sources
        copy_vendored_gems unless @minimal
        copy_native_binary
        copy_user_app
        write_boot_script
        write_launcher
        write_info_plist
        copy_icon if @icon
        strip_unnecessary_files
        @bytecode ? compile_bytecode : check_boot
        sign_bundle
        dmg = create_dmg if @dmg
        report(dmg)
        dmg || app_path
      end

      # The environment the bundled Ruby runs in, with res standing for Contents/Resources: written
      # into the launcher as "$RES", and a real path when the packager runs that Ruby itself.
      def runtime_env(res)
        ruby_lib = "#{res}/runtime/ruby/lib/ruby"
        stdlib = [
          "site_ruby/#{RUBY_ABI}", "site_ruby/#{RUBY_ABI}/#{ruby_platform_dir}", "site_ruby",
          "vendor_ruby/#{RUBY_ABI}", "vendor_ruby/#{RUBY_ABI}/#{ruby_platform_dir}", "vendor_ruby",
          RUBY_ABI, "#{RUBY_ABI}/#{ruby_platform_dir}",
        ]
        {
          "RUBYLIB" => (load_dirs.map { |dir| "#{res}/scarpe/#{dir}" } + stdlib.map { |dir| "#{ruby_lib}/#{dir}" }).join(":"),
          "GEM_HOME" => "#{res}/runtime/gems",
          "GEM_PATH" => "#{res}/runtime/gems",
          "SCARPE_DISPLAY_SERVICE" => "native",
        }
      end

      # Where Contents/Resources will be once the app is installed: what the bytecode is compiled for.
      def installed_resources
        dir = File.exist?(@install_dir) ? File.realpath(@install_dir) : File.expand_path(@install_dir)
        File.join(dir, "#{@name}.app", "Contents", "Resources")
      end

      private

      # A --name as a bundle name: slashes, colons and control characters cannot be in a file
      # name, and a leading dot would hide the app.
      def given_name(name)
        clean = name.to_s.gsub(%r{[/:[:cntrl:]]}, "").strip.sub(/\A\.+/, "")
        clean.empty? ? nil : clean
      end

      # Under Contents/Resources/scarpe/: the sources, then the vendored gems' lib directories.
      def load_dirs
        SOURCES + VENDORED_GEMS.map { |name| "gems/#{name}/lib" }
      end

      def resources_path
        File.join(app_path, "Contents", "Resources")
      end

      def binary_path
        File.join(app_path, "Contents", "MacOS", BINARY)
      end

      def copy_scarpe_sources
        log "📚 Copying Scarpe, Lacci and scarpe-components from #{@scarpe_root}..."
        dest = File.join(resources_path, "scarpe")
        SOURCES.each do |dir|
          FileUtils.mkdir_p(File.join(dest, dir))
          FileUtils.cp_r(File.join(@scarpe_root, dir, "."), File.join(dest, dir))
        end
        LEAVE_OUT.each { |path| FileUtils.rm_rf(File.join(dest, "lib", path)) }
        (SOURCE_FILES + manual_pictures).each do |file|
          source = File.join(@scarpe_root, file)
          next unless File.exist?(source)

          FileUtils.mkdir_p(File.dirname(File.join(dest, file)))
          FileUtils.cp(source, File.join(dest, file))
        end
      end

      # The pictures the manual shows (![man-app.png](man-app.png)), which sit beside it.
      def manual_pictures
        manual = File.join(@scarpe_root, "docs/static/manual.md")
        return [] unless File.exist?(manual)

        File.read(manual, encoding: Encoding::UTF_8).scan(/!\[[^\]]*\]\(([^)\/]+)\)/).flatten.uniq.map { |name| "docs/static/#{name}" }
      end

      def copy_vendored_gems
        log "💎 Copying #{VENDORED_GEMS.join(" and ")} from #{Gem.dir}..."
        licenses = File.join(resources_path, "licenses")
        FileUtils.mkdir_p(licenses)
        VENDORED_GEMS.each do |name|
          spec = Gem::Specification.find_by_name(name)
          dest = File.join(resources_path, "scarpe", "gems", name)
          FileUtils.mkdir_p(dest)
          FileUtils.cp_r(File.join(spec.gem_dir, "lib"), dest)
          Dir.glob(File.join(spec.gem_dir, "{MIT-LICENSE,LICENSE*,COPYING,BSDL}")).each do |license|
            FileUtils.cp(license, File.join(licenses, "#{name}-#{File.basename(license)}"))
          end
        end
      end

      def copy_native_binary
        source = native_binary
        log "🦀 Copying #{BINARY} from #{source}..."
        check_binary_arch(source)
        FileUtils.cp(source, binary_path)
        FileUtils.chmod(0o755, binary_path)
        log "   ⚠️  strip failed; shipping the binary unstripped" unless system("strip", "-x", binary_path, [:out, :err] => File::NULL)

        licenses = File.join(resources_path, "licenses")
        FileUtils.mkdir_p(licenses)
        Dir.glob(File.join(@scarpe_root, "native", "assets", "fonts", "*-LICENSE")).each { |license| FileUtils.cp(license, licenses) }
      end

      # SCARPE_NATIVE_BIN, or the crate's release build, rebuilt first when missing or older than
      # its sources (the same rule the shim follows in development, DESIGN 5.2).
      def native_binary
        explicit = ENV["SCARPE_NATIVE_BIN"].to_s
        return File.expand_path(explicit) unless explicit.empty?

        crate = File.join(@scarpe_root, "native")
        binary = File.join(crate, "target", "release", BINARY)
        build_native_binary(crate) if stale?(binary, crate)
        binary
      end

      def stale?(binary, crate)
        return true unless File.exist?(binary)

        built_at = File.mtime(binary)
        sources = Dir.glob(File.join(crate, "{src/**/*,Cargo.toml,Cargo.lock}")).select { |f| File.file?(f) }
        sources.any? { |source| File.mtime(source) > built_at }
      end

      def build_native_binary(crate)
        log "🦀 Building #{BINARY} (cargo build --release)..."
        cargo = ENV["CARGO"] || (system("which cargo", out: File::NULL) ? "cargo" : File.expand_path("~/.cargo/bin/cargo"))
        system(cargo, "build", "--release", chdir: crate) || raise("cargo build --release failed in #{crate}")
      end

      def check_binary_arch(binary)
        archs = `lipo -archs #{Shellwords.escape(binary)} 2>/dev/null`.split
        raise "#{binary} is not a macOS executable (is SCARPE_NATIVE_BIN pointing at a stand-in?)" if archs.empty?
        raise "#{binary} is built for #{archs.join(", ")}, not #{@arch}" unless archs.include?(@arch)
      end

      def write_boot_script
        FileUtils.cp(File.join(TEMPLATES, "native_boot.rb"), File.join(resources_path, "boot.rb"))
      end

      def write_launcher
        template = File.read(File.join(TEMPLATES, "native_launcher.sh.erb"))
        launcher = File.join(app_path, "Contents", "MacOS", "scarpe-launcher")
        File.write(launcher, ERB.new(template, trim_mode: "-").result(binding))
        FileUtils.chmod(0o755, launcher)
      end

      def strip_minimal(gems_dir, ruby_dir, **options)
        super
        MINIMAL_KEEPS.each do |entry|
          relative = File.join("lib", "ruby", RUBY_ABI, format(entry, platform: ruby_platform_dir))
          source = File.join(runtime_cache_path, relative)
          next unless File.exist?(source)

          FileUtils.mkdir_p(File.dirname(File.join(ruby_dir, relative)))
          FileUtils.cp_r(source, File.join(ruby_dir, relative))
        end
      end

      # Compiling runs the bundled Ruby through `require "scarpe"`, so it is also the proof that
      # the bundle boots: a library the strip removed shows up here, not on someone's desktop.
      def compile_bytecode
        log "⚡ Compiling Ruby to bytecode for #{installed_resources}..."
        output = run_bundled_ruby(<<~RUBY, File.realpath(resources_path), installed_resources)
          require "scarpe/package/bytecode"
          files = Scarpe::Package::Bytecode.compile_bundle(ARGV[0], ARGV[1], dirs: %w[scarpe app]) { require "scarpe" }
          puts "compiled \#{files.size} files"
        RUBY
        log "   #{output.lines.last.to_s.strip}"
      end

      def check_boot
        log "🔎 Checking the bundled Ruby can load Scarpe..."
        run_bundled_ruby('require "scarpe"')
      end

      def run_bundled_ruby(script, *args)
        resources = File.realpath(resources_path)
        env = runtime_env(resources).merge("HOME" => Dir.home, "PATH" => "/usr/bin:/bin")
        ruby = File.join(resources, "runtime", "ruby", "bin.real", "ruby")
        output, status = Open3.capture2e(env, ruby, "-e", script, *args, unsetenv_others: true, chdir: File.join(resources, "app"))
        vlog output
        raise "The bundled Ruby cannot load Scarpe, so the app would not start:\n#{output}" unless status.success?

        output
      end

      # Nested code first, then the bundle (the base class signs the Ruby side and the .app).
      def sign_bundle
        system("codesign", "--force", "--sign", "-", "--timestamp=none", binary_path, [:out, :err] => File::NULL) ||
          raise("codesign failed on #{binary_path}")
        super
      end

      def report(dmg)
        log ""
        log "✅ Created #{File.basename(app_path)} (#{megabytes(disk_bytes(app_path))})"
        {
          BINARY => disk_bytes(binary_path),
          "Ruby runtime" => disk_bytes(File.join(resources_path, "runtime")),
          "Scarpe, Lacci, components" => disk_bytes(File.join(resources_path, "scarpe")),
          "bytecode" => disk_bytes(File.join(resources_path, Bytecode::DIR)),
        }.each { |part, bytes| log "   #{part.ljust(26)} #{megabytes(bytes)}" }
        log "✅ Created #{File.basename(dmg)} (#{megabytes(File.size(dmg))})" if dmg
        log ""
        log "   Run it:  #{File.join(app_path, "Contents", "MacOS", "scarpe-launcher")}"
        log "   Bytecode is used when the app runs from #{File.dirname(File.dirname(installed_resources))}" if @bytecode
      end

      def disk_bytes(path)
        return 0 unless File.exist?(path)

        `du -sk #{Shellwords.escape(path)}`.split.first.to_i * 1024
      end

      def megabytes(bytes)
        "#{(bytes / 1024.0 / 1024.0).round(1)} MB"
      end
    end
  end
end
