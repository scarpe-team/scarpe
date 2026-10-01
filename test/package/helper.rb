# frozen_string_literal: true

# Helpers for the packager's tests (rake package_test).

require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require "minitest/autorun"

module PackageTestHelpers
  ROOT = File.expand_path("../..", __dir__)
  LIB = File.join(ROOT, "lib")
  PROBE = File.join(ROOT, "scripts", "native_first_frame_probe.rb")
  TRAVELING_RUBY = File.join(Dir.home, ".scarpe", "packager-cache", "traveling-ruby-3.4.7-macos-arm64-full")
  NATIVE_BINARY = File.join(ROOT, "native", "target", "release", "scarpe-native")

  # A temporary directory, by its real path (macOS hands out /var/..., which is /private/var/...),
  # removed after the test.
  def scratch_dir
    dir = File.realpath(Dir.mktmpdir("scarpe-package-test"))
    @scratch_dirs = (@scratch_dirs || []) << dir
    dir
  end

  def teardown
    (@scratch_dirs || []).each { |dir| FileUtils.rm_rf(dir) }
    super
  end

  def write(root, relative, content)
    path = File.join(root, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    path
  end

  # stdout of a fresh Ruby running script with lib/ on the load path; fails the test if it fails.
  def ruby_output(script, *args)
    out, err, status = Open3.capture3(RbConfig.ruby, "-I", LIB, "-e", script, *args)
    assert status.success?, "ruby failed:\n#{out}\n#{err}"
    out
  end
end
