# frozen_string_literal: true

require_relative "helper"
require "minitest/mock"

class ChildTest < Minitest::Test
  include NativeTestHelpers
  Child = Scarpe::Native::Child

  def setup
    @dir = Dir.mktmpdir("scarpe-native-child")
    @log = File.join(@dir, "child.log")
  end

  def teardown
    @child&.close
    FileUtils.rm_rf(@dir)
  end

  def start(script = [], binary: FAKE_CHILD)
    File.write(File.join(@dir, "script.json"), JSON.generate(script))
    with_env("FAKE_CHILD_LOG" => @log, "FAKE_CHILD_SCRIPT" => File.join(@dir, "script.json")) do
      @child = Child.new([binary])
    end
  end

  def received
    File.readlines(@log).map { |line| JSON.parse(line) }
  end

  def test_handshake
    start
    assert_equal "fake", @child.version
    assert_equal [{ "t" => "hello", "v" => 1, "pid" => Process.pid }], received
  end

  def test_request_returns_the_reply
    start
    assert_equal "pong", @child.request(:ping)["value"]
  end

  def test_events_a_request_causes_wait_in_the_inbox
    start([{ "on" => "req:ping", "emit" => [{ "t" => "event", "name" => "click", "target" => 5, "args" => [] }] }])
    @child.request(:ping)
    assert_equal [{ "t" => "event", "name" => "click", "target" => 5, "args" => [] }], @child.messages
    assert_empty @child.messages
  end

  def test_posts_are_buffered_until_flush
    start
    @child.post(t: "props", id: 1, props: { "text" => "é" })
    @child.request(:ping) # a round trip, so the log is written
    refute_includes received.map { |m| m["t"] }, "flush", "a request does not need a flush"
    assert_equal({ "t" => "props", "id" => 1, "props" => { "text" => "é" } }, received[1])

    @child.post(t: "destroy", id: 1)
    @child.flush
    @child.request(:ping)
    assert_equal(%w[destroy flush], received[3, 2].map { |m| m["t"] })
  end

  def test_flush_with_nothing_buffered_sends_nothing
    start
    @child.flush
    @child.request(:ping)
    assert_equal(%w[hello req], received.map { |m| m["t"] })
  end

  def test_a_crash_while_waiting_raises_with_the_stderr_tail
    start([{ "on" => "req:ping", "crash" => "thread 'main' panicked at src/runtime.rs:42" }])
    error = assert_raises(Scarpe::Native::ChildDied) { capture_subprocess_io { @child.request(:ping) } }
    assert_match(/exited with status 101/, error.message)
    assert_match(%r{panicked at src/runtime.rs:42}, error.message)
    assert @child.dead?
  end

  def test_a_pid_file_it_cannot_write_still_starts_the_child
    with_env("SCARPE_NATIVE_PID_FILE" => File.join(@dir, "missing", "renderer.pid")) { start }
    assert_equal "pong", @child.request(:ping)["value"]
  end

  def test_a_missing_binary_is_reported
    assert_raises(Scarpe::Native::ChildNotFound) { Child.new([File.join(@dir, "nope")]) }
  end

  # A double-click passes no flags, so the command is the binary's path alone. Ruby runs a lone
  # string through /bin/sh when it holds a parenthesis ("(Rust)" is a syntax error there) and
  # splits it at spaces otherwise ("For Noah.app" becomes a missing ".../For").
  def test_a_bundle_named_with_spaces_and_parentheses_starts_it_with_no_flags
    skip_on_windows("a macOS bundle's binary has no .exe for Windows to start")
    ["ZARKING (Rust).app", "For Noah.app"].each do |bundle|
      binary = File.join(@dir, bundle, "Contents", "MacOS", "scarpe-native")
      FileUtils.mkdir_p(File.dirname(binary))
      FileUtils.cp(FAKE_CHILD, binary, preserve: true)

      start([], binary: binary)
      assert_equal "fake", @child.version, bundle
      @child.close
    end
  end

  def test_close_ends_the_child
    start
    @child.close
    assert @child.dead? || @child.exit_status
    assert_equal 0, @child.exit_status.exitstatus
  end

  def test_binary_path_prefers_scarpe_native_bin
    with_env("SCARPE_NATIVE_BIN" => "/opt/scarpe-native") do
      assert_equal "/opt/scarpe-native", Scarpe::Native::Binary.path
    end
  end

  # An installed gem ships the crate but is no place to run cargo (review): a scarpe-native on
  # PATH comes first, and only a git checkout of Scarpe builds its own.
  def test_a_scarpe_native_on_path_comes_before_building_one
    bin = File.join(@dir, "bin")
    FileUtils.mkdir_p(bin)
    binary = File.join(bin, "scarpe-native#{Scarpe::Native::Binary::EXE}")
    File.write(binary, "#!/bin/sh\n")
    File.chmod(0o755, binary)
    with_env("SCARPE_NATIVE_BIN" => nil, "PATH" => bin) do
      Scarpe::Native::Binary.stub(:build, -> { flunk "ran cargo" }) do
        assert_equal binary, Scarpe::Native::Binary.path
      end
    end
  end

  def test_only_a_git_checkout_with_the_crate_counts_as_one
    installed_gem = File.join(@dir, "gems", "scarpe-0.5.0")
    FileUtils.mkdir_p(File.join(installed_gem, "native"))
    File.write(File.join(installed_gem, "native", "Cargo.toml"), "")
    refute Scarpe::Native::Binary.checkout?(root: installed_gem), "the crate ships in the gem, .git does not"

    File.write(File.join(installed_gem, ".git"), "gitdir: elsewhere\n") # a worktree's .git is a file
    assert Scarpe::Native::Binary.checkout?(root: installed_gem)
    assert Scarpe::Native::Binary.checkout?, "and the tests run from one"
  end

  def test_outside_a_checkout_with_nothing_on_path_it_says_so_instead_of_building
    with_env("SCARPE_NATIVE_BIN" => nil, "PATH" => @dir) do
      Scarpe::Native::Binary.stub(:checkout?, false) do
        Scarpe::Native::Binary.stub(:build, -> { flunk "ran cargo" }) do
          error = assert_raises(Scarpe::Native::ChildNotFound) { Scarpe::Native::Binary.path }
          assert_match(/SCARPE_NATIVE_BIN/, error.message)
        end
      end
    end
  end

  def test_the_gem_leaves_out_the_research_and_the_rust_tests
    files = Gem::Specification.load(File.join(ROOT, "scarpe.gemspec")).files
    assert_includes files, "native/src/main.rs", "the crate itself still ships"
    assert_empty files.grep(%r{\Anative/(research|tests)/}), "reports, fixtures and golden PNGs stay home"
  end

  def test_a_binary_older_than_any_crate_source_is_stale
    crate = File.join(@dir, "crate")
    FileUtils.mkdir_p(File.join(crate, "src", "layout"))
    source = File.join(crate, "src", "layout", "mod.rs")
    binary = File.join(@dir, "scarpe-native")
    [File.join(crate, "Cargo.toml"), source, binary].each { |file| File.write(file, "") }

    assert Scarpe::Native::Binary.stale?(binary: File.join(@dir, "missing"), crate: crate)
    File.utime(Time.now - 60, Time.now - 60, source, File.join(crate, "Cargo.toml"))
    refute Scarpe::Native::Binary.stale?(binary: binary, crate: crate)
    File.utime(Time.now + 60, Time.now + 60, source)
    assert Scarpe::Native::Binary.stale?(binary: binary, crate: crate)
  end
end
