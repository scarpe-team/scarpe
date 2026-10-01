# frozen_string_literal: true

require_relative "helper"
require "scarpe/package"
require "minitest/mock"

# `scarpe package` choosing between webview and native, and the pieces a native build writes.
# Native packages are macOS apps, so the tests ask for one by name (--target macos) and run the
# same on a Linux host; only what needs macOS tools checks the host.
class PackageTest < Minitest::Test
  include PackageTestHelpers

  def setup
    @app = write(scratch_dir, "hello_app.rb", "Shoes.app { para 'hi' }\n")
  end

  def test_native_flag_picks_the_native_packager
    options = Scarpe::Package.parse_args([@app, "--native", "--install-dir", "/Users/Shared", "--no-bytecode", "--target", "macos"])

    assert_equal({ app_file: @app, native: true, install_dir: "/Users/Shared", bytecode: false, target_os: "macos" }, options)
    assert_instance_of Scarpe::Package::Native, Scarpe::Package.packager_for(options, env: {})
  end

  def test_scarpe_display_service_native_picks_the_native_packager
    options = Scarpe::Package.parse_args([@app, "--target", "macos"])

    assert_instance_of Scarpe::Package::Native, Scarpe::Package.packager_for(options, env: { "SCARPE_DISPLAY_SERVICE" => "native" })
    assert_instance_of Scarpe::Package, Scarpe::Package.packager_for(options, env: {})
  end

  def test_native_packages_are_for_macos
    error = assert_raises(RuntimeError) { Scarpe::Package::Native.new(@app, target_os: "linux") }
    assert_match(/macOS/, error.message)
  end

  # SCARPE_NATIVE_BIN can point at test/native/fake_child.rb in a test shell; that must not ship.
  def test_only_a_mach_o_binary_gets_packaged
    packager = Scarpe::Package::Native.new(@app, target_os: "macos")
    script = write(scratch_dir, "fake_child.rb", "#!/usr/bin/env ruby\n")

    error = assert_raises(RuntimeError) { packager.send(:check_binary_arch, script) }
    assert_match(/not a macOS executable/, error.message)
    # lipo, and a Mach-O Ruby to read, are only on a Mac.
    packager.send(:check_binary_arch, RbConfig.ruby) if RUBY_PLATFORM.include?("darwin") && RbConfig.ruby.end_with?("/ruby")
  end

  def test_bytecode_is_compiled_for_the_install_dir
    skip_on_windows_for_mac_paths
    packager = Scarpe::Package::Native.new(@app, install_dir: "/Applications", target_os: "macos")

    assert_equal "/Applications/HelloApp.app/Contents/Resources", packager.installed_resources
  end

  # native/research/05 section 2.3: a "scarpe-" prefix match took scarpe-components for scarpe.
  def test_find_gem_dir_does_not_take_scarpe_components_for_scarpe
    gems_root = scratch_dir
    FileUtils.mkdir_p(File.join(gems_root, "gems", "scarpe-components-0.2.2"))
    packager = Scarpe::Package.new(@app)

    assert_nil packager.send(:find_gem_dir, gems_root, "scarpe", nil, nil)
    assert_equal "scarpe-components-0.2.2", packager.send(:find_gem_dir, gems_root, "scarpe-components", nil, nil)

    FileUtils.mkdir_p(File.join(gems_root, "gems", "scarpe-0.5.0"))
    assert_equal "scarpe-0.5.0", packager.send(:find_gem_dir, gems_root, "scarpe", nil, nil)
  end

  def test_the_launcher_runs_the_native_service_from_the_bundle
    launcher = render_launcher

    assert_includes launcher, %(export SCARPE_DISPLAY_SERVICE="native")
    assert_includes launcher, %(export SCARPE_NATIVE_BIN="$MACOS/scarpe-native")
    assert_includes launcher, %(export RUBYLIB="$RES/scarpe/lib:$RES/scarpe/lacci/lib:$RES/scarpe/scarpe-components/lib:)
    assert_includes launcher, %("$RES/boot.rb" hello_app.rb)
    refute_match(/SCARPE_DISPLAY=/, launcher, "SCARPE_DISPLAY is read by nothing")
    assert system("bash", "-n", "-c", launcher), "the launcher is not valid bash"
  end

  def test_the_launcher_quotes_the_app_name
    @app = write(scratch_dir, "it's $HOME.rb", "Shoes.app {}\n")

    assert_includes render_launcher, %("$RES/boot.rb" it\\'s\\ \\$HOME.rb)
  end

  def test_the_boot_script_never_loads_the_webview
    boot = File.read(File.join(Scarpe::Package::Native::TEMPLATES, "native_boot.rb"))

    refute_match(%r{scarpe/wv}, boot, "scarpe/wv sets Shoes::Log and Shoes::Spec a second time")
    assert_includes boot, %(ENV["SCARPE_DISPLAY_SERVICE"] = "native")
  end

  # Nothing reads SCARPE_DISPLAY; SCARPE_DISPLAY_SERVICE picks the display service (lib/scarpe.rb).
  def test_webview_packages_name_their_display_service
    output = scratch_dir
    packager = Scarpe::Package.new(@app, output_dir: output)
    FileUtils.mkdir_p(File.join(packager.app_path, "Contents", "MacOS"))
    FileUtils.mkdir_p(File.join(packager.app_path, "Contents", "Resources"))
    packager.send(:write_boot_script)
    packager.send(:write_launcher)

    boot = File.read(File.join(packager.app_path, "Contents", "Resources", "boot.rb"))
    launcher = File.read(File.join(packager.app_path, "Contents", "MacOS", "scarpe-launcher"))
    assert_includes boot, "ENV['SCARPE_DISPLAY_SERVICE'] = 'wv_local'"
    assert_includes launcher, "export SCARPE_DISPLAY_SERVICE=wv_local"
    refute_match(/SCARPE_DISPLAY\b(?!_)/, boot + launcher)
  end

  def test_include_can_be_given_more_than_once
    options = Scarpe::Package.parse_args([@app, "--native", "--include", "art", "--include", "playhouse", "--target", "macos"])

    assert_equal %w[art playhouse], options[:includes]
    assert_equal %w[art playhouse], Scarpe::Package.packager_for(options, env: {}).instance_variable_get(:@includes)
  end

  # ZARKING draws from art/ and playhouse/ beside its file; the packager only carried images/,
  # assets/, fonts/ and sounds/, so a packaged copy lost every picture.
  def test_included_files_and_folders_land_where_the_app_looks
    root = scratch_dir
    app = write(root, "dash.rb", "Shoes.app {}\n")
    write(root, "art/pet/idle_1.png", "png")
    write(root, "playhouse/today.md", "bonjour")
    write(root, "notes/deep/tip.txt", "tip")
    elsewhere = write(scratch_dir, "shared.txt", "shared")
    packager = Scarpe::Package::Native.new(app, output_dir: scratch_dir, target_os: "macos",
      includes: ["art", "playhouse/", "notes/deep/tip.txt", elsewhere])
    app_dir = File.join(packager.app_path, "Contents", "Resources", "app")
    FileUtils.mkdir_p(app_dir)

    packager.send(:copy_user_app)

    assert_equal "png", File.read(File.join(app_dir, "art", "pet", "idle_1.png"))
    assert_equal "bonjour", File.read(File.join(app_dir, "playhouse", "today.md"))
    assert_equal "tip", File.read(File.join(app_dir, "notes", "deep", "tip.txt")), "a path inside the app's folder keeps its place"
    assert_equal "shared", File.read(File.join(app_dir, "shared.txt")), "a path outside it lands under its own name"
  end

  def test_a_missing_include_stops_the_build
    packager = Scarpe::Package::Native.new(@app, output_dir: scratch_dir, includes: ["nowhere"], target_os: "macos")
    FileUtils.mkdir_p(File.join(packager.app_path, "Contents", "Resources", "app"))

    error = assert_raises(RuntimeError) { packager.send(:copy_user_app) }
    assert_match(/--include nowhere/, error.message)
  end

  # sanitize_name turned "ZARKING (Rust)" into ZarkingRust.app and "For Noah" into ForNoah.app.
  def test_a_native_package_keeps_the_name_it_was_given
    skip_on_windows_for_mac_paths
    packager = Scarpe::Package::Native.new(@app, output_dir: scratch_dir, name: "ZARKING (Rust)", target_os: "macos")

    assert_equal "ZARKING (Rust).app", File.basename(packager.app_path)
    assert_equal "/Applications/ZARKING (Rust).app/Contents/Resources", packager.installed_resources
    assert_equal "com.scarpe.zarkingrust", packager.instance_variable_get(:@bundle_id)
    assert_equal "ab.app", File.basename(Scarpe::Package::Native.new(@app, name: "..a/b:\t", target_os: "macos").app_path), "no slash, colon, control character or leading dot"
    assert_equal "HelloApp.app", File.basename(Scarpe::Package::Native.new(@app, target_os: "macos").app_path), "a name made from the file stays CamelCase"
    assert system("bash", "-n", "-c", render_launcher(name: "ZARKING (Rust)")), "the launcher is valid bash under that name"
  end

  def test_the_info_plist_holds_a_given_name_whole
    skip "Windows keeps no < or > in a file name" if Gem.win_platform?
    packager = Scarpe::Package::Native.new(@app, output_dir: scratch_dir, name: "Salt & <Pepper>", target_os: "macos")
    FileUtils.mkdir_p(File.join(packager.app_path, "Contents"))
    packager.send(:write_info_plist)
    plist = File.join(packager.app_path, "Contents", "Info.plist")

    assert_includes File.read(plist), "<string>Salt &amp; &lt;Pepper&gt;</string>"
    # plutil, which reads the plist as macOS will, is only on a Mac.
    if RUBY_PLATFORM.include?("darwin")
      assert system("plutil", "-lint", "-s", plist), "Info.plist does not parse"
      name, status = Open3.capture2("plutil", "-extract", "CFBundleName", "raw", "-o", "-", plist)
      assert status.success?
      assert_equal "Salt & <Pepper>", name.strip
    end
  end

  # Builds share ~/.scarpe/packager-cache. Each used to stage its disk image in the same
  # dmg-staging folder and empty it first, under any other build still copying into it.
  def test_a_dmg_build_leaves_other_builds_staging_alone
    cache = scratch_dir
    other = write(cache, "dmg-staging/Other.app/Contents/Info.plist", "another build's")
    packager = Scarpe::Package::Native.new(@app, output_dir: scratch_dir, target_os: "macos")
    packager.instance_variable_set(:@cache_dir, cache)
    staged = nil
    # ditto and hdiutil stand in: note where the app was staged, and make no image.
    fake_system = lambda do |*args|
      staged ||= File.dirname(args[2]) if args[0] == "ditto"
      true
    end

    packager.stub(:system, fake_system) { packager.send(:create_dmg) }

    assert File.exist?(other), "another build's staging survives"
    refute_equal File.join(cache, "dmg-staging"), staged, "this build stages in a folder of its own"
    refute File.exist?(staged), "and removes it"
  end

  # The PNG icon's iconset lived at one fixed path in the cache too.
  def test_a_png_icon_leaves_other_builds_iconset_alone
    cache = scratch_dir
    other = write(cache, "icon.iconset/icon_16x16.png", "another build's")
    icon = File.join(ROOT, "spec", "support", "assets", "red-40x30.png")
    packager = Scarpe::Package::Native.new(@app, output_dir: scratch_dir, icon: icon, target_os: "macos")
    packager.instance_variable_set(:@cache_dir, cache)
    FileUtils.mkdir_p(File.join(packager.app_path, "Contents", "Resources"))

    packager.send(:copy_icon)

    # sips and iconutil, which make the icon, are only on a Mac.
    if RUBY_PLATFORM.include?("darwin")
      assert File.exist?(File.join(packager.app_path, "Contents", "Resources", "red-40x30.icns")), "the icon was made"
    end
    assert File.exist?(other), "another build's iconset survives"
    assert_equal ["icon.iconset"], Dir.children(cache), "this build's own folder is gone"
  end

  private

  # A macOS package's paths are Unix paths, which File.expand_path gives a drive letter on Windows.
  def skip_on_windows_for_mac_paths
    skip "macOS packages are not built on Windows" if Gem.win_platform?
  end

  def render_launcher(name: nil)
    output = scratch_dir
    packager = Scarpe::Package::Native.new(@app, output_dir: output, name: name, target_os: "macos")
    FileUtils.mkdir_p(File.join(packager.app_path, "Contents", "MacOS"))
    packager.send(:write_launcher)
    File.read(File.join(packager.app_path, "Contents", "MacOS", "scarpe-launcher"))
  end
end
