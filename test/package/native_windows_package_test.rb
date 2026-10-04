# frozen_string_literal: true

require_relative "helper"
require "scarpe/package"
require "json"
require "timeout"

# Opt in because this downloads Traveling Ruby, compiles the launcher and runs a real renderer.
# The Windows packaging CI job sets the flag. Every application process stays headless.
class NativeWindowsPackageTest < Minitest::Test
  include PackageTestHelpers

  APP = <<~'RUBY'
    require "json"
    require "fiddle"
    require "openssl"
    require "net/http"
    require_relative "lib/رسالة"
    console = Fiddle::Function.new(Fiddle.dlopen("kernel32.dll")["GetConsoleWindow"], [], Fiddle::TYPE_VOIDP).call.to_i
    proof = { ruby: RUBY_VERSION, console: console, greeting: PackageGreeting::TEXT,
      args: ARGV.last(2), certificate: File.file?(ENV.fetch("SSL_CERT_FILE")),
      webview: $LOADED_FEATURES.any? { |path| path.include?("webview") } }
    Shoes.app(width: 240, height: 120) do
      background "#dde"
      para PackageGreeting::TEXT
      button "Packaged"
      proof[:image_size] = imagesize("assets/red.png")
      proof[:font] = font("assets/Pacifico.ttf")
    end
    Scarpe::Native.on_first_heartbeat do
      automation = Scarpe::Native::DisplayService.instance.automation
      proof[:frames] = automation.frames(1)
      automation.snapshot(ENV.fetch("SCARPE_PACKAGE_SNAPSHOT"), scale: 1)
      File.write(ENV.fetch("SCARPE_PACKAGE_REPORT"), JSON.generate(proof))
      Shoes.quit
    end
  RUBY

  def setup
    skip "Windows package integration is opt-in" unless Gem.win_platform? && ENV["SCARPE_WINDOWS_PACKAGE_TESTS"] == "1"
    @root = scratch_dir
    @results = ENV["SCARPE_WINDOWS_PACKAGE_RESULTS"] || File.join(@root, "results")
    FileUtils.mkdir_p(@results)
  end

  def test_the_distributed_bundle_runs_after_extraction_and_reports_startup_failures
    source = File.join(@root, "source")
    app = write(source, "reader.rb", APP)
    write(source, "lib/رسالة.rb", "module PackageGreeting; TEXT = 'مرحبا'; end\n")
    FileUtils.mkdir_p(File.join(source, "assets"))
    FileUtils.cp(File.join(ROOT, "spec/support/assets/red-40x30.png"), File.join(source, "assets/red.png"))
    FileUtils.cp(File.join(ROOT, "spec/support/assets/Pacifico.ttf"), File.join(source, "assets/Pacifico.ttf"))
    # One 32-bit DIB pixel, with an AND mask, in a valid ICO directory.
    dib = [40, 1, 2, 1, 32, 0, 4, 0, 0, 0, 0].pack("V3v2V6") + "\x00\x00\xff\xff\0\0\0\0".b
    icon = write(source, "app.ico", [0, 1, 1].pack("v3") + [1, 1, 0, 0, 1, 32, dib.bytesize, 22].pack("C4v2V2") + dib)
    name = "Reader's [الجامع]"
    output = File.join(@root, "Build's [الجامع]")
    package = Scarpe::Package::Native.new(app, name: name, target_os: "windows", arch: "x86_64",
      output_dir: output, includes: ["lib"], icon: icon)
    bundle = package.build!
    archive = File.join(output, "#{name}-x86_64-windows.zip")
    assert File.file?(archive)
    assert File.file?(File.join(bundle, "ruby/bin.real/rubyw.exe"))
    refute File.exist?(File.join(bundle, "#{name}.bat"))
    refute File.exist?(File.join(bundle, "scarpe/lib/scarpe/wv.rb"))

    relocated = File.join(@root, "Extracted elsewhere - الجامع")
    command = "Expand-Archive -LiteralPath '#{archive.gsub("'", "''")}' -DestinationPath '#{relocated.gsub("'", "''")}' -Force -ErrorAction Stop"
    text, status = Open3.capture2e("powershell", "-NoProfile", "-NonInteractive", "-Command", command)
    assert status.success?, text
    FileUtils.rm_rf(bundle)
    FileUtils.rm_rf(source)
    bundle = File.join(relocated, name)
    launcher = File.join(bundle, "#{name}.exe")
    [launcher, File.join(bundle, "scarpe-native.exe")].each do |binary|
      pe = File.binread(binary)
      header = pe.byteslice(60, 4).unpack1("V")
      assert_equal 2, pe.byteslice(header + 92, 2).unpack1("v"), "#{File.basename(binary)} must use the GUI subsystem"
    end

    status, text, log = launch(launcher, "success", {}, "argument with spaces", "الجامع")
    assert_equal 0, status.exitstatus, "#{text}\n#{log}"
    proof = JSON.parse(File.read(File.join(@results, "report.json")))
    assert_equal Scarpe::Package::TRAVELING_RUBY_VERSION, proof.fetch("ruby")
    assert_equal 0, proof.fetch("console"), "Ruby must not acquire a console"
    assert_equal "مرحبا", proof.fetch("greeting")
    assert_equal ["argument with spaces", "الجامع"], proof.fetch("args")
    assert proof.fetch("certificate")
    refute proof.fetch("webview")
    assert_equal [40, 30], proof.fetch("image_size")
    assert_includes proof.fetch("font"), "Pacifico"
    assert_operator proof.fetch("frames"), :>=, 1
    assert_equal "\x89PNG".b, File.binread(File.join(@results, "frame.png"), 4)

    failure = write(@root, "failure.rb", 'warn "deliberate startup failure"; exit 17')
    status, text, log = launch(launcher, "child-failure", { "SCARPE_RUN_FILE" => failure })
    assert_equal 17, status.exitstatus, "#{text}\n#{log}"
    assert_includes log, "deliberate startup failure"
    assert_includes text, "Application exited with code 17"

    incomplete = File.join(@root, "Incomplete - الجامع", "#{name}.exe")
    FileUtils.mkdir_p(File.dirname(incomplete))
    FileUtils.cp(launcher, incomplete)
    status, text, log = launch(incomplete, "missing-files")
    assert_equal 1, status.exitstatus, "#{text}\n#{log}"
    assert_includes text, "Application files are missing"
    assert_includes log, "Extract the whole ZIP"
  end

  private

  def launch(launcher, label, extra_env = {}, *args)
    data = File.join(@root, "data-#{label}")
    env = {
      "SCARPE_NATIVE_HEADLESS" => "1", "SCARPE_NATIVE_GHOST" => nil, "SCARPE_RUN_FILE" => nil,
      "SCARPE_PACKAGE_REPORT" => File.join(@results, "report.json"),
      "SCARPE_PACKAGE_SNAPSHOT" => File.join(@results, "frame.png"), "LOCALAPPDATA" => data,
      # No installed Ruby/Rust on PATH, and deliberately wrong host Ruby and renderer settings.
      "PATH" => [File.join(ROOT, "spec/support/fakebin"), File.join(ENV.fetch("SystemRoot"), "System32"), ENV.fetch("SystemRoot")].join(";"),
      "RUBYLIB" => "Z:/not-the-runtime", "GEM_HOME" => "Z:/not-the-gems", "GEM_PATH" => "Z:/not-the-gems",
      "RUBYOPT" => "-rthis_file_does_not_exist", "BUNDLE_GEMFILE" => "Z:/no-Gemfile", "BUNDLE_PATH" => "Z:/no-bundle",
      "SCARPE_DISPLAY_SERVICE" => "wv_local", "SCARPE_NATIVE_BIN" => "Z:/not-the-renderer.exe",
      "SSL_CERT_FILE" => "Z:/no-certificates", "SSL_CERT_DIR" => "Z:/no-certificates",
    }.merge(extra_env)
    text = nil
    status = nil
    Open3.popen2e(env, [launcher, launcher], *args) do |input, output, waiter|
      input.close
      reader = Thread.new { output.read }
      begin
        status = Timeout.timeout(45) { waiter.value }
        text = reader.value
      rescue Timeout::Error
        system("taskkill.exe", "/PID", waiter.pid.to_s, "/T", "/F", out: File::NULL, err: File::NULL)
        raise
      ensure
        reader.join
      end
    end
    log_path = File.join(data, File.basename(launcher, ".exe"), "launcher.log")
    log = File.file?(log_path) ? File.read(log_path) : "No launcher log was created"
    File.write(File.join(@results, "#{label}.log"), "#{text}\n#{log}")
    [status, text, log]
  end
end
