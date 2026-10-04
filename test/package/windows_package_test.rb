# frozen_string_literal: true

require_relative "helper"
require "scarpe/package"
require "minitest/mock"
require "rubygems/package"
require "zlib"

class WindowsPackageTest < Minitest::Test
  include PackageTestHelpers

  def setup
    @source = scratch_dir
    @app = write(@source, "hello_app.rb", "Shoes.app { para 'hi' }\n")
  end

  def test_native_windows_selection_and_portable_paths
    options = Scarpe::Package.parse_args([@app, "--native", "--target", "windows", "--arch", "x86_64"])
    package = Scarpe::Package.packager_for(options, env: {})

    assert_instance_of Scarpe::Package::Native, package
    assert_equal File.join(package.windows_output_path, "HelloApp.exe"), package.windows_exe_path
    assert_equal File.join(package.windows_output_path, "scarpe-native.exe"), package.send(:binary_path)
    assert_equal package.windows_output_path, package.send(:resources_path)
    refute package.instance_variable_get(:@bytecode), "a portable folder has no fixed install path for bytecode"
  end

  def test_windows_names_preserve_unicode_and_exclude_reserved_names
    assert_equal "My App - الجامع.exe", File.basename(packager(name: "My App - الجامع").windows_exe_path)
    assert_equal "abcd.exe", File.basename(packager(name: "a<>b\"c|?*d... ").windows_exe_path)
    assert_equal "_CON.exe", File.basename(packager(name: "CON").windows_exe_path)
    assert_equal "_Con.exe", File.basename(packager(app: write(@source, "con.rb", "")).windows_exe_path)
  end

  def test_windows_environment_uses_semicolons_and_bundled_paths
    env = packager.runtime_env("C:/My Apps/الجامع")
    paths = env.fetch("RUBYLIB").split(";")

    assert_equal "C:/My Apps/الجامع/scarpe/lib", paths.first
    assert_includes paths, "C:/My Apps/الجامع/ruby/lib/ruby/3.4.0/x64-mingw-ucrt"
    assert_equal "C:/My Apps/الجامع/runtime/gems", env.fetch("GEM_HOME")
    assert_equal env.fetch("GEM_HOME"), env.fetch("GEM_PATH")
    assert_equal "native", env.fetch("SCARPE_DISPLAY_SERVICE")
  end

  def test_included_code_and_assets_are_carried_into_windows_packages
    write(@source, "lib/رسالة.rb", "MESSAGE = 'مرحبا'\n")
    write(@source, "assets/picture.png", "png")
    package = nil
    _, warnings = capture_io { package = packager(includes: ["lib"]) }
    refute_match(/ignored/, warnings)
    package.send(:create_windows_structure)
    destination = File.join(package.windows_output_path, "app")

    package.send(:copy_user_app, destination: destination, entrypoint: "main.rb")

    assert_equal File.read(@app), File.read(File.join(destination, "main.rb"))
    assert_equal "MESSAGE = 'مرحبا'\n", File.read(File.join(destination, "lib/رسالة.rb"))
    assert_equal "png", File.read(File.join(destination, "assets/picture.png"))
  end

  def test_only_windows_x64_executables_are_accepted
    package = packager
    pe = "MZ".b.ljust(64, "\0")
    pe[60, 4] = [64].pack("V")
    binary = write(@source, "renderer.exe", pe + "PE\0\0".b + [0x8664].pack("v"))
    package.send(:check_binary_arch, binary)

    ["#!/bin/sh\n", "MZ", pe + "PE\0\0".b + [0xaa64].pack("v"), pe + "PE\0\0".b + [0x14c].pack("v")].each do |invalid|
      File.binwrite(binary, invalid)
      error = assert_raises(RuntimeError) { package.send(:check_binary_arch, binary) }
      assert_match(/Windows x86_64 executable/, error.message)
    end
  end

  def test_windows_build_constraints_are_explicit
    error = assert_raises(RuntimeError) { packager(arch: "arm64") }
    assert_match(/x86_64/, error.message)
    error = assert_raises(RuntimeError) { packager(minimal: true) }
    assert_match(/--minimal/, error.message)
    Gem.stub(:win_platform?, false) do
      error = assert_raises(RuntimeError) { packager.build! }
      assert_match(/Build native Windows packages on Windows/, error.message)
    end
  end

  def test_windows_zip_passes_quoted_literal_paths_to_dotnet
    package = packager(name: "Reader's [الجامع]")
    command = nil
    fake_capture = lambda do |*args|
      command = args
      File.binwrite(File.join(package.instance_variable_get(:@output_dir), "Reader's [الجامع]-x86_64-windows.zip"), "zip")
      ["", Struct.new(:success?).new(true)]
    end
    Gem.stub(:win_platform?, true) do
      Open3.stub(:capture2e, fake_capture) { package.send(:create_windows_zip) }
    end

    assert_equal %w[powershell -NoProfile -NonInteractive -Command], command.first(4)
    assert_includes command[4], "::CreateFromDirectory('#{package.windows_output_path.gsub("'", "''")}', "
    assert_includes command[4], "$ErrorActionPreference = 'Stop'"
  end

  def test_failed_archive_creation_is_not_reported_as_success
    package = packager
    Gem.stub(:win_platform?, true) do
      Open3.stub(:capture2e, ["archive failed", Struct.new(:success?).new(false)]) do
        error = assert_raises(RuntimeError) { package.send(:create_windows_zip) }
        assert_match(/Could not create Windows archive/, error.message)
        assert_match(/archive failed/, error.message)
      end
    end
  end

  def test_runtime_extraction_works_with_an_absolute_cache_path
    package = packager
    package.instance_variable_set(:@cache_dir, scratch_dir)
    Zlib::GzipWriter.open(package.send(:tarball_cache_path)) do |gzip|
      Gem::Package::TarWriter.new(gzip) do |tar|
        tar.add_file_simple("runtime.txt", 0o644, 5) { |file| file.write("hello") }
      end
    end

    package.send(:extract_runtime)

    assert_equal "hello", File.read(File.join(package.send(:runtime_cache_path), "runtime.txt"))
  end

  def test_failed_packaging_tools_report_their_output
    error = assert_raises(RuntimeError) do
      packager.send(:run_windows_tool, RbConfig.ruby, "-e", 'warn "compiler failed"; exit 7')
    end
    assert_match(/compiler failed/, error.message)
  end

  private

  def packager(app: @app, **options)
    Scarpe::Package::Native.new(app, target_os: "windows", arch: "x86_64", output_dir: scratch_dir, **options)
  end
end
