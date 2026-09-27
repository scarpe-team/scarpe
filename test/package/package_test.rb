# frozen_string_literal: true

require_relative "helper"
require "scarpe/package"

# `scarpe package`: the pieces it writes and the gems it picks.
class PackageTest < Minitest::Test
  include PackageTestHelpers

  def setup
    @app = write(scratch_dir, "hello_app.rb", "Shoes.app { para 'hi' }\n")
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
end
