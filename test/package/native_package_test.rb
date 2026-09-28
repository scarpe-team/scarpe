# frozen_string_literal: true

require_relative "helper"
require "json"

# Builds one real native .app with `scarpe package --native` and runs its launcher headless, the
# way a double-click runs it minus the window. Needs the cached Traveling Ruby and the release
# scarpe-native binary; skips without them.
class NativePackageTest < Minitest::Test
  include PackageTestHelpers

  RED_PNG = File.join(ROOT, "spec", "support", "assets", "red-40x30.png")
  PACIFICO = File.join(ROOT, "spec", "support", "assets", "Pacifico.ttf")
  APP = <<~RUBY
    Shoes.app(width: 240, height: 120) do
      background "#dde"
      button "Packaged"
      warn "scarpe-imagesize \#{imagesize(#{RED_PNG.inspect}).inspect}"
      warn "scarpe-font \#{font(#{PACIFICO.inspect}).inspect}"
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
       scarpe/CHANGELOG.md scarpe/docs/static/manual.md scarpe/docs/static/man-app.png bytecode/manifest licenses/Inter-LICENSE app/packaged_app.rb
       boot.rb].each do |file|
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
    # Started with no LANG, as Finder starts it, Ruby would read files as US-ASCII.
    assert_equal "UTF-8", run[:probe]["encoding"], "files read as UTF-8"
  end

  # Image#size, full_width and imagesize read files through FastImage, a gem, and a native
  # bundle carries no gems of its own.
  def test_image_sizes_read_in_the_bundle
    run = launch(bundle)

    assert_includes run[:stderr], "scarpe-imagesize [40, 30]"
  end

  # font(path) reads the family names out of the file, which are UTF-16 text, and a native
  # bundle's Ruby carries no encoding transcoders. It answered nil there, and a font it does
  # not name is never handed to the renderer: the Kids apps drew their words without Fredoka.
  def test_fonts_are_named_and_loaded_in_the_bundle
    run = launch(bundle)

    assert_includes run[:stderr], 'scarpe-font ["Pacifico"]'
    refute_match(/failed to load encoding/, run[:stderr])
  end

  # A double-click sends the app's output to /dev/null, so the launcher writes it to
  # ~/Library/Logs/<name>/launcher.log; a terminal (here, a pipe) still gets it directly.
  def test_output_nobody_can_read_goes_to_the_log
    home = scratch_dir
    log = File.join(home, "Library", "Logs", "PackagedApp", "launcher.log")
    env = { "HOME" => home, "PATH" => "/usr/bin:/bin", "SCARPE_NATIVE_HEADLESS" => "1", "SCARPE_NATIVE_GHOST" => "1" }
    launcher = File.join(bundle, "Contents", "MacOS", "scarpe-launcher")

    launch(bundle, "HOME" => home)
    refute File.exist?(log), "output someone reads stays out of the log"

    finder_like = { unsetenv_others: true, chdir: "/", out: File::NULL, err: File::NULL }
    assert system(env, launcher, **finder_like), "the launcher failed"
    assert_match(/^==== .* pid \d+: /, File.read(log))
    assert_match(/^scarpe-probe /, File.read(log))
  end

  # SCARPE_RUN_FILE: the launcher runs that file on the bundled Ruby and Scarpe instead of the
  # app's own, in SCARPE_RUN_DIR with SCARPE_RUN_ARGS as its ARGV. It is how a packaged app's
  # Shoes.run_program starts a program (DESIGN 5.5).
  def test_the_launcher_runs_a_given_file
    dir = scratch_dir
    program = write(dir, "given.rb", "$stderr.puts \"given file in \#{File.basename(Dir.pwd)}, \#{ARGV.inspect}\"\n")
    Dir.mkdir(File.join(dir, "elsewhere"))
    env = { "SCARPE_RUN_FILE" => program, "SCARPE_RUN_DIR" => File.join(dir, "elsewhere"), "SCARPE_RUN_ARGS" => '["one"]' }

    status, err = run_launcher(bundle, env)

    assert status.success?, err
    assert_includes err, 'given file in elsewhere, ["one"]'
    refute_includes err, "scarpe-probe", "the app's own file did not run"
  end

  # A double-click starts the app from launchd's bare environment, in /, its output going to
  # its log. Its Shoes.run_program starts the launcher again for the program, which reports its
  # output and errors to the app and stops when told, on the bundled runtime throughout.
  def test_a_packaged_app_runs_a_program_of_its_own
    home = scratch_dir
    dir = scratch_dir
    write(dir, "program.rb", <<~PROGRAM)
      puts "hello from the program"
      Shoes.app { para "the program"; timer(0.2) { raise "the program broke" } }
    PROGRAM
    parent = write(dir, "parent.rb", <<~PARENT)
      Shoes.app do
        para "the app"
        program = Shoes.run_program(File.join(__dir__, "program.rb"))
        heard = []
        program.on_output { |stream, line| heard << [stream, line] }
        renderer = nil
        program.on_error do |err|
          heard << [err["during"], err["message"]]
          renderer = program.instance_variable_get(:@driver).renderer_pid
          program.stop
        end
        program.on_exit do |status|
          File.write(File.join(__dir__, "heard.json"), JSON.generate(heard: heard, signaled: status.signaled?, pids: [program.pid, renderer]))
          Shoes.quit
        end
      end
    PARENT
    env = { "HOME" => home, "PATH" => "/usr/bin:/bin", "SCARPE_NATIVE_HEADLESS" => "1", "SCARPE_NATIVE_GHOST" => "1", "SCARPE_RUN_FILE" => parent }
    launcher = File.join(bundle, "Contents", "MacOS", "scarpe-launcher")
    app = Process.spawn(env, launcher, unsetenv_others: true, chdir: "/", in: File::NULL, out: File::NULL, err: File::NULL, pgroup: true)
    begin
      _, status = wait_for(app, 90)
      log = File.join(home, "Library", "Logs", "PackagedApp", "launcher.log")
      assert status&.success?, "the app did not end cleanly: #{status.inspect}\n#{File.exist?(log) ? File.read(log) : "(no log)"}"
      heard = JSON.parse(File.read(File.join(dir, "heard.json")))
      assert_equal [["stdout", "hello from the program"], ["timer", "the program broke"]], heard["heard"]
      assert heard["signaled"], "stop ended it"
      heard["pids"].each do |pid|
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
        sleep 0.05 until `ps -o pid= -p #{Integer(pid)}`.strip.empty? || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        assert_empty `ps -o pid= -p #{Integer(pid)}`.strip, "the program and its renderer are gone (#{pid})"
      end
    ensure
      Process.kill("KILL", -app) rescue nil
    end
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

  # The launcher's exit status and stderr, headless, with no probe to wait for.
  def run_launcher(app, env = {})
    env = { "HOME" => Dir.home, "PATH" => "/usr/bin:/bin", "SCARPE_NATIVE_HEADLESS" => "1", "SCARPE_NATIVE_GHOST" => "1" }.merge(env)
    _out, err, status = Open3.capture3(env, File.join(app, "Contents", "MacOS", "scarpe-launcher"), unsetenv_others: true)
    [status, err]
  end

  # [pid, status] once the process ends, or [pid, nil] after `seconds`, when it gets KILL.
  def wait_for(pid, seconds)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    until (done = Process.wait2(pid, Process::WNOHANG))
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        Process.kill("KILL", -pid)
        Process.wait(pid)
        return [pid, nil]
      end
      sleep 0.05
    end
    done
  end

  # Headless unless env says otherwise, and a window it does open is a ghost nobody can see.
  def launch(app, env = {})
    env = { "HOME" => Dir.home, "PATH" => "/usr/bin:/bin", "SCARPE_NATIVE_HEADLESS" => "1", "SCARPE_NATIVE_GHOST" => "1" }.merge(env)
    launcher = File.join(app, "Contents", "MacOS", "scarpe-launcher")
    _out, err, status = Open3.capture3(env, launcher, unsetenv_others: true)
    probe = err[/^scarpe-probe (.*)$/, 1]
    flunk "no first frame from #{launcher}:\n#{err}" unless probe

    { status: status, stderr: err, probe: JSON.parse(probe) }
  end
end
