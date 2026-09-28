# frozen_string_literal: true

require_relative "helper"
require "scarpe/package"

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

  private

  def render_launcher
    output = scratch_dir
    packager = Scarpe::Package::Native.new(@app, output_dir: output, target_os: "macos")
    FileUtils.mkdir_p(File.join(packager.app_path, "Contents", "MacOS"))
    packager.send(:write_launcher)
    File.read(File.join(packager.app_path, "Contents", "MacOS", "scarpe-launcher"))
  end
end
