# frozen_string_literal: true

class Scarpe::Package::Native
  # The existing Windows packager supplies the Ruby runtime and ZIP archive. A native bundle
  # replaces the webview gems and batch file with Scarpe's sources, renderer and GUI launcher.
  def build_windows!
    raise "Build native Windows packages on Windows with Rust MSVC and the Windows SDK" unless Gem.win_platform?
    raise "Windows launcher icons must be .ico files" if @icon && File.extname(@icon).downcase != ".ico"

    ensure_runtime_cached
    create_windows_structure
    copy_ruby_runtime_windows
    FileUtils.cp(File.join(runtime_cache_path, "lib", "ca-bundle.crt"), File.join(windows_output_path, "ruby", "lib"))
    FileUtils.mkdir_p(File.join(resources_path, "runtime", "gems"))
    copy_scarpe_sources
    copy_vendored_gems
    copy_native_binary
    copy_user_app(destination: File.join(resources_path, "app"), entrypoint: "main.rb")
    write_boot_script
    write_windows_ruby_manifests
    write_native_windows_launcher
    check_windows_boot
    create_windows_zip
    log "✅ Created #{windows_output_path}"
    log "   Run it: #{windows_exe_path}"
    windows_output_path
  end

  def windows_exe_path
    File.join(windows_output_path, "#{@name}.exe")
  end

  private

  def windows_package_name(name)
    clean = name.gsub(/[<>:"\/\\|?*[:cntrl:]]/, "").sub(/[. ]+\z/, "")
    clean = "ScarpeApp" if clean.empty?
    clean = "_#{clean}" if clean.match?(/\A(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|\z)/i)
    clean
  end

  # Reject a Unix binary or the wrong Windows architecture before copying it into a bundle.
  def check_windows_binary(binary)
    valid = File.open(binary, "rb") do |file|
      dos = file.read(64)
      next false unless dos && dos.bytesize == 64 && dos.start_with?("MZ")

      file.seek(dos.byteslice(60, 4).unpack1("V"))
      file.read(6) == "PE\0\0\x64\x86".b
    end
    raise "#{binary} is not a Windows x86_64 executable" unless valid
  end

  # Ruby resolves its standard library before boot.rb can change an encoding. Merge, rather
  # than replace, its existing manifest so Unicode install paths work from process startup.
  def write_windows_ruby_manifests
    Dir.mktmpdir("scarpe-manifest", @cache_dir) do |dir|
      %w[ruby rubyw].each do |name|
        binary = File.join(windows_output_path, "ruby", "bin.real", "#{name}.exe")
        manifest = File.join(dir, "#{name}.manifest")
        run_windows_tool("mt.exe", "-nologo", "-inputresource:#{binary};#1", "-out:#{manifest}")
        run_windows_tool("mt.exe", "-nologo", "-manifest", manifest,
          File.join(TEMPLATES, "native_windows_utf8.manifest"), "-outputresource:#{binary};#1")
      end
    end
  end

  def write_native_windows_launcher
    Dir.mktmpdir("scarpe-launcher", @cache_dir) do |dir|
      args = [ENV["RUSTC"] || "rustc", File.join(TEMPLATES, "native_windows_launcher.rs"),
        "--crate-name", "scarpe_launcher", "--edition", "2021", "--target", "x86_64-pc-windows-msvc",
        "-O", "-C", "target-feature=+crt-static", "-o", windows_exe_path]
      linker = windows_linker
      args.concat(["-C", "linker=#{linker}"]) if linker
      if @icon
        # A fixed relative filename avoids putting user paths in resource-script source code.
        FileUtils.cp(@icon, File.join(dir, "app.ico"))
        File.write(File.join(dir, "app.rc"), "1 ICON \"app.ico\"\n")
        run_windows_tool("rc.exe", "/nologo", "/fo", "app.res", "app.rc", chdir: dir)
        args.concat(["-C", "link-arg=#{File.join(dir, 'app.res')}"])
      end
      run_windows_tool({ "SCARPE_PACKAGE_RUBY_ABI" => RUBY_ABI, "SCARPE_PACKAGE_RUBY_FLAGS" => RUBY_FLAGS.join(" ") }, *args)
    end
    check_windows_binary(windows_exe_path)
  end

  def check_windows_boot
    env = runtime_env(resources_path).merge("RUBYOPT" => nil, "BUNDLE_GEMFILE" => nil, "BUNDLE_PATH" => nil,
      "BUNDLE_BIN_PATH" => nil, "BUNDLER_SETUP" => nil)
    ruby = File.join(windows_output_path, "ruby", "bin.real", "ruby.exe")
    output, status = Open3.capture2e(env, ruby, *RUBY_FLAGS, "-e", 'require "scarpe"', chdir: File.join(resources_path, "app"))
    raise "The bundled Ruby cannot load Scarpe, so the app would not start:\n#{output}" unless status.success?
  end

  # RubyInstaller puts MSYS's unrelated link.exe on PATH ahead of the MSVC linker.
  def windows_linker
    ENV["CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER"] ||
      (File.join(ENV["VCToolsInstallDir"], "bin", "Hostx64", "x64", "link.exe") if ENV["VCToolsInstallDir"])
  end

  def run_windows_tool(*command, **options)
    output, status = Open3.capture2e(*command, **options)
    vlog output
    raise "Windows packaging command failed: #{command.find { |arg| arg.is_a?(String) }}\n#{output}" unless status.success?
  rescue Errno::ENOENT => error
    raise "Windows packaging needs Rust MSVC and Windows SDK tools on PATH: #{error.message}"
  end
end
