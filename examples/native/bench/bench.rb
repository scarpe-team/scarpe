# frozen_string_literal: true

# The native display service's benchmarks (native/PERF.md). Each bench runs a small Shoes app in
# its own processes through drive.rb (cold start runs the real exe/scarpe), then reads what both
# sides measured (SCARPE_NATIVE_STATS: the shim's ruby.json, Rust's rust.json, the driver's
# driver.json) and prints one table.
#
#   ruby examples/native/bench/bench.rb                         every bench
#   ruby examples/native/bench/bench.rb ovals typing            some of them
#   ruby examples/native/bench/bench.rb --ruby PATH --yjit      another Ruby, with YJIT on
#   options: --seconds N (measured stretch, default 5)  --runs N (cold starts, default 5)
#            --bundler (cold start through `exe/scarpe --dev`, as in a dev checkout)  --json OUT
#
# Windows are ghosts (SCARPE_NATIVE_GHOST: real frames, but invisible and click-through, never
# taking focus; native/PERF.md says how that can differ from a visible window) and close by themselves.

require "json"
require "optparse"
require "rbconfig"
require "tmpdir"

module Bench
  HERE = __dir__
  ROOT = File.expand_path("../../..", HERE)
  DRIVE = File.join(HERE, "drive.rb")
  BOOT_PROBE = File.join(HERE, "boot_probe.rb")
  HELLO = File.join(ROOT, "examples", "hello_world.rb")
  TIMEOUT = 120
  TYPED = "Hello from the other side of the pipe"

  Row = Struct.new(:bench, :measure, :value, :unit)

  class Runner
    ALL = %w[ovals ovals_headless backdrop typing typing_headless startup idle clock rebuild memory].freeze

    def initialize(argv)
      @ruby = RbConfig.ruby
      @yjit = false
      @seconds = 5.0
      @runs = 5
      @bundler = false
      @json = nil
      @only = OptionParser.new do |o|
        o.on("--ruby PATH") { |path| @ruby = path }
        o.on("--yjit") { @yjit = true }
        o.on("--seconds N", Float) { |n| @seconds = n }
        o.on("--runs N", Integer) { |n| @runs = n }
        o.on("--bundler") { @bundler = true }
        o.on("--json OUT") { |path| @json = File.expand_path(path) }
      end.parse(argv)
      @only = ALL if @only.empty?
      unknown = @only - ALL
      abort("unknown bench #{unknown.join(", ")}; pick from #{ALL.join(" ")}") unless unknown.empty?
      @rows = []
      @raw = {}
    end

    def run
      puts "#{ruby_description}, #{machine}"
      @only.each do |bench|
        $stderr.print("#{bench}... ")
        started = monotonic
        send("bench_#{bench}")
        $stderr.puts(format("%.1fs", monotonic - started))
      end
      print_table
      File.write(@json, JSON.pretty_generate("rows" => @rows.map(&:to_h), "raw" => @raw)) if @json
    end

    private

    # 500 ovals under animate(60) in a real (ghost) window.
    def bench_ovals
      result = drive("ovals.rb", "run", @seconds)
      frame_rate("ovals", result)
      where_time_goes("ovals", result)
    end

    # The same app headless at 2x, 60 paced steps a second, each painted offscreen.
    def bench_ovals_headless
      result = drive("ovals.rb", "paced", @seconds, headless: true)
      frame_rate("ovals headless", result)
      where_time_goes("ovals headless", result)
    end

    # One small ball over a busy, still window: what a frame costs when almost nothing changed.
    def bench_backdrop
      result = drive("backdrop.rb", "run", @seconds)
      frame_rate("backdrop", result)
      where_time_goes("backdrop", result)
    end

    def bench_typing
      keystrokes("typing", drive("typing.rb", "type", TYPED))
    end

    def bench_typing_headless
      keystrokes("typing headless", drive("typing.rb", "type", TYPED, headless: true))
    end

    # `scarpe --native hello_world.rb` from nothing to its first frame on screen, @runs times.
    def bench_startup
      runs = Array.new(@runs) { cold_start }
      @raw["startup"] = runs
      median = ->(key) { runs.map { |r| r[key] }.compact.then { |v| v.empty? ? nil : percentile(v, 50) } }
      label = @bundler ? "startup (exe/scarpe --dev)" : "startup (exe/scarpe)"
      add(label, "spawn to first frame on screen (median of #{@runs})", median.(:total), "ms")
      [
        [:ruby_boot, "Ruby VM boot"], [:ruby_load, "Ruby: load Scarpe + Lacci + shim, start the app"],
        [:child_exec, "Rust child exec"], [:event_loop, "Rust: event loop running, hello answered (from its start)"],
        [:fonts, "Rust: system fonts loaded (from its start)"], [:app_build, "Ruby: app built, run sent (from spawn)"],
        [:window, "Rust: window open (after run)"], [:first_frame, "first layout + paint + present"]
      ].each { |key, name| add(label, name, median.(key), "ms") }
    end

    def bench_idle
      cpu("idle (still app)", drive("still.rb", "idle", @seconds * 2))
    end

    def bench_clock
      cpu("clock (every 1s)", drive("clock.rb", "idle", @seconds * 2))
    end

    # Clear a slot of 2000 paras and fill it again, five times.
    def bench_rebuild
      result = drive("rebuild.rb", "click", "rebuild", 5)
      samples = result.dig(:driver, "round_trip_ms") || []
      add("rebuild 2000 paras", "click to rebuilt frame on screen (median)", percentile(samples, 50), "ms")
      frames = frames_in_window(result)
      busy = frames.select { |f| f[2] > 1.0 } # the frames that carried a rebuild
      per = ->(col) { busy.empty? ? nil : busy.sum { |f| f[col] } / busy.size }
      add("rebuild 2000 paras", "Rust: parse #{busy.size} rebuilds' messages (per rebuild)", per.(1), "ms")
      add("rebuild 2000 paras", "Rust: apply destroys + creates", per.(2), "ms")
      add("rebuild 2000 paras", "Rust: layout", per.(3), "ms")
      add("rebuild 2000 paras", "Rust: paint", per.(4), "ms")
      add("rebuild 2000 paras", "Rust: present", per.(5), "ms")
      window = result.dig(:driver, "window") || {}
      clicks = samples.size.nonzero? || 1
      add("rebuild 2000 paras", "lines sent per rebuild", (window.dig("ruby_counters", "lines") || 0) / clicks.to_f, "")
      add("rebuild 2000 paras", "Ruby: JSON encode per rebuild", (window.dig("ruby_phases", "encode", "total_ms") || 0) / clicks, "ms")
    end

    def bench_memory
      hello = drive(HELLO, "run", 1)
      many = drive("drawables.rb", "run", 1)
      [["hello world", hello], ["2000 drawables", many]].each do |name, result|
        window = result.dig(:driver, "window") || {}
        add("memory", "#{name}: Ruby footprint / RSS", mb_pair(window, "ruby"), "MB")
        add("memory", "#{name}: Rust footprint / RSS", mb_pair(window, "rust"), "MB")
      end
    end

    # Reporting

    def mb_pair(window, side)
      %w[footprint rss].map { |kind| window["#{side}_#{kind}_kb"] }.map { |kb| kb ? fmt(kb / 1024.0) : "n/a" }.join(" / ")
    end

    def frame_rate(bench, result)
      window = result.dig(:driver, "window") or return add(bench, "no measurement: #{result.dig(:driver, "error")}", nil, "")
      frames = frames_in_window(result)
      intervals = frames.each_cons(2).map { |a, b| (b[0] - a[0]) * 1000.0 }
      add(bench, "frames per second", frames.size / window["wall"], "fps")
      add(bench, "frame interval p50 / p95 / max", intervals_summary(intervals), "ms")
      add(bench, "animate ticks per second (Ruby)", ticks(window) / window["wall"], "/s")
      add(bench, "Ruby CPU", 100.0 * window["ruby_cpu"] / window["wall"], "%")
      add(bench, "Rust CPU", window["rust_cpu"] && 100.0 * window["rust_cpu"] / window["wall"], "%")
    end

    def where_time_goes(bench, result)
      window = result.dig(:driver, "window") or return
      phases = window["ruby_phases"] || {}
      n = ticks(window).nonzero? || 1
      encode = phases.dig("encode", "total_ms").to_f
      add(bench, "Ruby handler per tick (Lacci + shim, less JSON)", (phases.dig("timers", "total_ms").to_f - encode) / n, "ms")
      add(bench, "Ruby JSON encode per tick", encode / n, "ms")
      add(bench, "pipe: bytes per tick", window.dig("ruby_counters", "bytes").to_f / n, "B")
      add(bench, "pipe: write per tick", phases.dig("write", "total_ms").to_f / n, "ms")
      add(bench, "pipe: ping round trip p50", percentile(result.dig(:driver, "ping_ms") || [], 50), "ms")
      frames = frames_in_window(result)
      return if frames.empty?

      %w[parse apply layout paint present].each.with_index(1) do |phase, col|
        add(bench, "Rust #{phase} per frame", frames.sum { |f| f[col] } / frames.size, "ms")
      end
    end

    def keystrokes(bench, result)
      trips = result.dig(:driver, "round_trip_ms") || []
      latency = result.dig(:rust, "input_latency_ms") || []
      add(bench, "key in -> frame showing it (Rust, p50 / p95)", "#{fmt(percentile(latency, 50))} / #{fmt(percentile(latency, 95))}", "ms")
      add(bench, "key req -> Ruby handler -> redrawn frame (p50 / p95)", "#{fmt(percentile(trips, 50))} / #{fmt(percentile(trips, 95))}", "ms")
      add(bench, "text arrived intact", result.dig(:driver, "text") == TYPED ? "yes" : "NO: #{result.dig(:driver, "text").inspect}", "")
    end

    def cpu(bench, result)
      window = result.dig(:driver, "window") or return add(bench, "no measurement", nil, "")
      add(bench, "Ruby CPU over #{window["wall"].round}s", 100.0 * window["ruby_cpu"] / window["wall"], "%")
      add(bench, "Rust CPU over #{window["wall"].round}s", window["rust_cpu"] && 100.0 * window["rust_cpu"] / window["wall"], "%")
      add(bench, "frames drawn per second", frames_in_window(result).size / window["wall"], "/s")
    end

    # Every animate tick that changed something ends in one flush.
    def ticks(window)
      window.dig("ruby_counters", "flushes").to_i
    end

    def frames_in_window(result)
      rust = result[:rust] or return []
      window = result.dig(:driver, "window") or return []
      from = window["from_unix"] - rust["started_unix"]
      to = window["to_unix"] - rust["started_unix"]
      rust["frames"].select { |f| f[0] > from && f[0] <= to }
    end

    def intervals_summary(intervals)
      return nil if intervals.empty?

      [50, 95].map { |p| fmt(percentile(intervals, p)) }.push(fmt(intervals.max)).join(" / ")
    end

    # Running things

    def drive(app, action, *args, headless: false)
      app = File.expand_path(app, HERE)
      with_stats_dir do |dir|
        env = child_env(dir, headless: headless)
        status = spawn_and_wait(env, [@ruby, DRIVE, app, action, *args.map(&:to_s)], chdir: File.dirname(app))
        read_results(dir).merge(status: status)
      end
    end

    def cold_start
      with_stats_dir do |dir|
        env = child_env(dir, headless: false, exit_after: 2)
        env["RUBYOPT"] = [ENV["RUBYOPT"], "-r#{BOOT_PROBE}"].compact.join(" ")
        command = [@ruby, File.join(ROOT, "exe", "scarpe"), *("--dev" if @bundler), "--native", HELLO]
        env["RUBYLIB"] = %w[lib lacci/lib scarpe-components/lib].map { |d| File.join(ROOT, d) }.join(":") unless @bundler
        spawned_at = unix_now
        spawn_and_wait(env, command, chdir: File.dirname(HELLO))
        timeline(spawned_at, read_results(dir), dir)
      end
    end

    # Every step of a cold start, in ms, measured against the moment we spawned Ruby.
    def timeline(spawned_at, results, dir)
      rust = results[:rust] || {}
      ruby = results[:ruby] || {}
      boot_file = File.join(dir, "boot.txt")
      boot = File.exist?(boot_file) ? File.read(boot_file).to_f : nil
      rust_at = ->(mark) { rust.dig("marks", mark) && rust["started_unix"] + rust["marks"][mark] }
      ruby_at = ->(mark) { ruby.dig("marks", mark) }
      ms = ->(from, to) { from && to && (to - from) * 1000.0 }
      {
        total: ms.(spawned_at, rust_at.("first_present")),
        ruby_boot: ms.(spawned_at, boot),
        ruby_load: ms.(boot, ruby_at.("spawn")),
        child_exec: ms.(ruby_at.("spawn"), rust["started_unix"]),
        event_loop: ms.(rust["started_unix"], rust_at.("ready")),
        fonts: ms.(rust["started_unix"], rust_at.("system_fonts_loaded") || rust_at.("fonts")),
        app_build: ms.(ruby_at.("spawn"), ruby_at.("run")),
        window: ms.(rust_at.("run"), rust_at.("window")),
        first_frame: ms.(rust_at.("window"), rust_at.("first_present")),
      }
    end

    def child_env(dir, headless:, exit_after: TIMEOUT)
      args = ["--exit-after", exit_after.to_s]
      args += ["--scale", "2"] if headless # a Retina window's pixels, so headless numbers compare
      {
        "SCARPE_NATIVE_STATS" => dir,
        "SCARPE_NATIVE_GHOST" => "1",
        "SCARPE_NATIVE_INACTIVE" => "1", # for a shim or binary older than the ghost flag
        "SCARPE_NATIVE_HEADLESS" => (headless ? "1" : nil),
        "SCARPE_NATIVE_ARGS" => args.join(" "),
        "SCARPE_NATIVE_LOG_LEVEL" => "error",
        "RUBY_YJIT_ENABLE" => (@yjit ? "1" : nil),
        "BUNDLE_GEMFILE" => File.join(ROOT, "Gemfile"),
      }
    end

    def with_stats_dir
      Dir.mktmpdir("scarpe-native-bench") { |dir| yield dir }
    end

    def read_results(dir)
      %w[driver rust ruby].to_h do |name|
        path = File.join(dir, "#{name}.json")
        [name.to_sym, File.exist?(path) ? JSON.parse(File.read(path)) : nil]
      end
    end

    def spawn_and_wait(env, command, chdir:)
      pid = Process.spawn(env, *command, chdir: chdir, pgroup: true, out: File::NULL, err: File::NULL, in: File::NULL)
      deadline = monotonic + TIMEOUT
      until (status = Process.wait2(pid, Process::WNOHANG)&.last)
        if monotonic > deadline
          Process.kill("KILL", -pid)
          return Process.wait2(pid).last
        end
        sleep(0.05)
      end
      status
    end

    # Output

    def add(bench, measure, value, unit)
      @rows << Row.new(bench, measure, value.is_a?(Numeric) ? value.round(3) : value, unit)
    end

    def print_table
      puts
      puts "| bench | measure | value |"
      puts "|---|---|---|"
      @rows.each { |row| puts "| #{row.bench} | #{row.measure} | #{[fmt(row.value), row.unit].reject(&:empty?).join(" ")} |" }
    end

    def fmt(value)
      case value
      when nil then "n/a"
      when Float then value.abs >= 100 ? value.round.to_s : format("%.2f", value)
      else value.to_s
      end
    end

    def percentile(values, pct)
      return nil if values.empty?

      sorted = values.sort
      sorted[((pct / 100.0) * (sorted.size - 1)).round]
    end

    def ruby_description
      `#{@ruby} -e 'print RUBY_DESCRIPTION'`.strip + (@yjit ? " with RUBY_YJIT_ENABLE=1" : "")
    end

    def machine
      chip = `sysctl -n machdep.cpu.brand_string 2>/dev/null`.strip
      "#{chip.empty? ? RUBY_PLATFORM : chip}, #{`sw_vers -productVersion 2>/dev/null`.strip}"
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def unix_now
      Process.clock_gettime(Process::CLOCK_REALTIME)
    end
  end
end

Bench::Runner.new(ARGV).run if $PROGRAM_NAME == __FILE__
