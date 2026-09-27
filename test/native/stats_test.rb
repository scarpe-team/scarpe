# frozen_string_literal: true

require_relative "helper"

# SCARPE_NATIVE_STATS (native/PERF.md): both sides report where their time went, and the
# counters cost nothing but a flag check when it is not set.
class StatsTest < Minitest::Test
  include NativeTestHelpers
  Stats = Scarpe::Native::Stats

  def teardown
    Stats.reset!
  end

  def test_off_unless_asked_and_timed_blocks_still_run
    with_stats(nil) do
      refute Stats.enabled?
      assert_equal 42, Stats.time(:encode) { 42 }
      Stats.count("lines")
      Stats.mark("ready")
      assert_empty Stats.report.values_at("phases", "counters", "marks").reduce(:merge)
    end
  end

  def test_tallies_phases_and_counts_and_keeps_the_first_mark
    Dir.mktmpdir do |dir|
      with_stats(dir) do
        2.times { Stats.time(:encode) { :done } }
        Stats.count("lines", 3)
        Stats.mark("ready")
        first = Stats.report["marks"]["ready"]
        Stats.mark("ready")
        Stats.write

        written = JSON.parse(File.read(File.join(dir, "ruby.json")))
        assert_equal 2, written["phases"]["encode"]["n"]
        assert_equal 3, written["counters"]["lines"]
        assert_equal first, written["marks"]["ready"]
        assert_operator written["cpu"]["ruby"], :>, 0
      end
    end
  end

  def test_a_real_run_leaves_both_reports_behind
    skip_without_real_binary
    Dir.mktmpdir do |stats|
      run = run_real(<<~APP, env: { "SCARPE_NATIVE_STATS" => stats }, test_code: <<~TEST)
        Shoes.app { para "Counted" }
      APP
        assert_operator wait_frames(1), :>=, 1
      TEST
      assert_spec_passed(run)

      ruby = JSON.parse(File.read(File.join(stats, "ruby.json")))
      rust = JSON.parse(File.read(File.join(stats, "rust.json")))
      assert_equal %w[pump ready run spawn], ruby["marks"].keys.sort & %w[pump ready run spawn]
      assert_operator ruby["counters"]["flushes"], :>=, 1
      assert_operator rust["phases"]["layout"]["n"], :>=, 1
      assert_operator rust["frames"].size, :>=, 1, "headless, every picture painted counts as a frame"
      assert rust["marks"].key?("first_paint")
    end
  end

  # A real window (a ghost through run_real), so only with SCARPE_NATIVE_WINDOWED_TESTS=1.
  def test_a_window_uses_its_frames_colour_space
    skip_without_real_binary
    skip "set SCARPE_NATIVE_WINDOWED_TESTS=1 to open real windows" unless ENV["SCARPE_NATIVE_WINDOWED_TESTS"]
    skip "only macOS colour-matches our frames" unless RUBY_PLATFORM.include?("darwin")
    Dir.mktmpdir do |stats|
      env = { "SCARPE_NATIVE_STATS" => stats, "SCARPE_NATIVE_INACTIVE" => "1" }
      run = run_real(<<~APP, headless: false, env: env, test_code: <<~TEST)
        Shoes.app { para "In colour" }
      APP
        assert_operator wait_frames(3), :>=, 3
      TEST
      assert_spec_passed(run)

      rust = JSON.parse(File.read(File.join(stats, "rust.json")))
      assert rust["marks"].key?("colour_space_matched"), "the window reads back DeviceRGB, the frames' colour space"
      assert_operator rust["phases"]["present"]["n"], :>=, 3
    end
  end

  private

  def with_stats(dir)
    saved = ENV["SCARPE_NATIVE_STATS"]
    ENV["SCARPE_NATIVE_STATS"] = dir
    Stats.reset!
    yield
  ensure
    ENV["SCARPE_NATIVE_STATS"] = saved
  end
end
