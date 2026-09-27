# frozen_string_literal: true

require_relative "helper"
require "json"

# Builds one real native .app with `scarpe package --native` and runs its launcher headless, the
# way a double-click runs it minus the window. Needs the cached Traveling Ruby and the release
# scarpe-native binary; skips without them.
class NativePackageTest < Minitest::Test
  include PackageTestHelpers

  APP = <<~RUBY
    Shoes.app(width: 240, height: 120) do
      background "#dde"
      button "Packaged"
    end
  RUBY

  class << self
    attr_accessor :built
  end

  def setup
    skip "no cached Traveling Ruby at #{TRAVELING_RUBY}" unless Dir.exist?(TRAVELING_RUBY)
    skip "no scarpe-native release build at #{NATIVE_BINARY}" unless File.executable?(NATIVE_BINARY)

    self.class.built ||= build
  end

  def test_the_bundle_carries_ruby_scarpe_and_the_binary
    contents = File.join(bundle, "Contents")

    assert File.executable?(File.join(contents, "MacOS", "scarpe-native"))
    assert File.executable?(File.join(contents, "MacOS", "scarpe-launcher"))
    assert File.executable?(File.join(contents, "Resources", "runtime", "ruby", "bin.real", "ruby"))
    %w[scarpe/lib/scarpe/native.rb scarpe/lacci/lib/shoes.rb scarpe/scarpe-components/lib/scarpe/components/version.rb
       scarpe/CHANGELOG.md bytecode/manifest licenses/Inter-LICENSE app/packaged_app.rb boot.rb].each do |file|
      assert File.exist?(File.join(contents, "Resources", file)), "missing Resources/#{file}"
    end
    %w[scarpe/lib/scarpe/wv.rb scarpe/lib/scarpe/package.rb].each do |file|
      refute File.exist?(File.join(contents, "Resources", file)), "Resources/#{file} should stay behind"
    end
  end

  def test_the_bundle_is_signed
    out, status = Open3.capture2e("codesign", "--verify", "--deep", "--strict", bundle)

    assert status.success?, out
  end

  def test_it_boots_headless_from_bytecode
    snapshot = File.join(scratch_dir, "first_frame.png")
    run = launch(bundle, "SCARPE_PROBE_SNAPSHOT" => snapshot)

    assert_equal 0, run[:status].exitstatus, run[:stderr]
    assert_operator run[:probe]["frames"], :>=, 1
    assert_operator run[:probe]["bytecode_hits"], :>, 50, "Lacci, the shim and the app should load from bytecode"
    assert_equal "\x89PNG".b, File.binread(snapshot, 4)
  end

  def test_a_moved_app_boots_from_source
    moved = File.join(scratch_dir, "PackagedApp.app")
    assert system("ditto", bundle, moved)

    run = launch(moved)

    assert_equal 0, run[:status].exitstatus, run[:stderr]
    assert_nil run[:probe]["bytecode_hits"], "bytecode compiled for another place must not load"
  end

  private

  def bundle
    self.class.built
  end

  # Packages the app with the first-frame probe appended, installed where it is built. The bundle
  # lives until the test process exits.
  def build
    dir = File.realpath(Dir.mktmpdir("scarpe-native-package"))
    Minitest.after_run { FileUtils.rm_rf(dir) }
    app = write(dir, "packaged_app.rb", APP + File.read(PROBE))
    command = [RbConfig.ruby, File.join(ROOT, "exe", "scarpe"), "package", app, "--native", "--output", dir, "--install-dir", dir]
    out, status = Open3.capture2e({ "SCARPE_NATIVE_BIN" => NATIVE_BINARY }, *command)
    flunk "scarpe package --native failed:\n#{out}" unless status.success?

    File.join(dir, "PackagedApp.app")
  end

  def launch(app, env = {})
    env = { "HOME" => Dir.home, "PATH" => "/usr/bin:/bin", "SCARPE_NATIVE_HEADLESS" => "1" }.merge(env)
    launcher = File.join(app, "Contents", "MacOS", "scarpe-launcher")
    _out, err, status = Open3.capture3(env, launcher, unsetenv_others: true)
    probe = err[/^scarpe-probe (.*)$/, 1]
    flunk "no first frame from #{launcher}:\n#{err}" unless probe

    { status: status, stderr: err, probe: JSON.parse(probe) }
  end
end
