# frozen_string_literal: true

# Runs one bench app the way `scarpe --native` does, then acts on it once it is on screen and
# quits. bench.rb starts it with SCARPE_NATIVE_STATS set; what the driver measures goes to
# driver.json in that directory, next to the shim's ruby.json and Rust's rust.json.
#
#   ruby drive.rb APP.rb run SECONDS        the app runs free; measure SECONDS of it after a warm-up
#   ruby drive.rb APP.rb idle SECONDS       as run, but hands off: nothing steps the pump but itself
#   ruby drive.rb APP.rb paced SECONDS      like run, but every pump step waits for a frame (headless paints)
#   ruby drive.rb APP.rb type KEYS          type KEYS into the first edit_line, one key at a time
#   ruby drive.rb APP.rb click TEXT TIMES   click TEXT, TIMES times, each time until it is drawn
#
# It loads Lacci and the shim straight from this checkout (no Bundler), so any Ruby 3.2+ works,
# which is how bench.rb compares Rubies and YJIT.

ROOT = File.expand_path("../../..", __dir__)
%w[lib lacci/lib scarpe-components/lib].each { |dir| $LOAD_PATH.unshift(File.join(ROOT, dir)) }
ENV["SCARPE_DISPLAY_SERVICE"] = "native"
ENV["SCARPE_NATIVE_GHOST"] ||= "1" # run by hand too, its window is a ghost (native/DESIGN.md 12)
require "scarpe"

module Bench
  # Acts on the running app from the first heartbeat, inside the pump, like `scarpe peek`.
  class Driver
    WARMUP = 2.0 # seconds before measuring: the first frames shape every string and fill the caches
    PINGS = 50

    def initialize(app_path, action, args)
      @app_path = File.expand_path(app_path)
      @action = action
      @args = args
      @report = { "action" => action, "args" => args }
    end

    def run
      Scarpe::Native.on_first_heartbeat do
        @report["first_heartbeat_unix"] = unix_now
        next watch_idly(*@args) if @action == "idle"

        @report["ping_ms"] = ping_times
        send("do_#{@action}", *@args)
      rescue StandardError => e
        @report["error"] = "#{e.class}: #{e.message}"
        warn("drive.rb: #{@report["error"]}")
      ensure
        unless @action == "idle"
          write_report
          Shoes.APPS.each(&:destroy)
        end
      end
      Shoes.run_app(@app_path)
    end

    private

    def do_run(seconds)
      automation.advance(WARMUP)
      measure_window { automation.advance(seconds.to_f) }
    end

    # Measures from a thread of its own, so the pump runs its own loop the way an app left alone
    # does, then ends the app the way Ctrl-C would. Only clocks and ps are read from here.
    def watch_idly(seconds)
      child = Scarpe::Native::DisplayService.instance.child
      Thread.new do
        sleep(WARMUP)
        before = idle_snapshot(child)
        sleep(seconds.to_f)
        after = idle_snapshot(child)
        @report["window"] = {
          "from_unix" => before[:unix], "to_unix" => after[:unix], "wall" => after[:wall] - before[:wall],
          "ruby_cpu" => after[:ruby_cpu] - before[:ruby_cpu],
          "rust_cpu" => after[:rust_cpu] && before[:rust_cpu] && after[:rust_cpu] - before[:rust_cpu],
        }
        write_report
        Process.kill("INT", Process.pid)
      end
    end

    def idle_snapshot(child)
      { unix: unix_now, wall: monotonic, ruby_cpu: Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID), rust_cpu: cpu_seconds(child.pid) }
    end

    # Headless, nothing is painted unless asked, so each timer tick is followed by a frame request:
    # the rate tells whether ticking and painting fit in a 60 fps budget without a window.
    def do_paced(seconds)
      automation.advance(WARMUP)
      pump = Scarpe::Native::DisplayService.instance.pump
      measure_window do
        deadline = monotonic + seconds.to_f
        while monotonic < deadline
          pump.step
          automation.frames(1)
        end
      end
    end

    # Each key goes in through Rust's input path, and we wait until a frame showing it is drawn.
    def do_type(keys)
      line = Shoes::App.find_drawables_by(Shoes::EditLine).first or raise "no edit_line to type into"
      automation.click({ id: line.linkable_id })
      automation.frames(2)
      samples = []
      measure_window do
        keys.to_s.each_char do |key|
          started = monotonic
          automation.key(key)
          automation.frames(1)
          samples << (monotonic - started) * 1000.0
          pause(0.05) # a fast typist, not a firehose
        end
      end
      @report["round_trip_ms"] = samples
      @report["text"] = line.text
    end

    # Lets the app run between keys the way it does between a person's keystrokes: the pump turns,
    # and only the app itself asks for frames.
    def pause(seconds)
      pump = Scarpe::Native::DisplayService.instance.pump
      deadline = monotonic + seconds
      pump.step while monotonic < deadline
    end

    # Clicks something whose handler redraws a lot, timing each click until it is drawn.
    def do_click(text, times)
      automation.frames(1)
      samples = []
      measure_window do
        Integer(times).times do
          started = monotonic
          automation.click({ text: text })
          automation.frames(1)
          samples << (monotonic - started) * 1000.0
        end
      end
      @report["round_trip_ms"] = samples
    end

    # A request with no work in it: the cost of the pipe and both event loops.
    def ping_times
      child = Scarpe::Native::DisplayService.instance.child
      Array.new(PINGS) do
        started = monotonic
        child.request(:ping)
        (monotonic - started) * 1000.0
      end
    end

    # Records the stretch's wall time, each side's CPU time and memory, and the pump's tallies.
    def measure_window
      child = Scarpe::Native::DisplayService.instance.child
      before = snapshot(child)
      yield
      after = snapshot(child)
      @report["window"] = {
        "from_unix" => before[:unix], "to_unix" => after[:unix],
        "wall" => after[:wall] - before[:wall],
        "ruby_cpu" => after[:ruby_cpu] - before[:ruby_cpu],
        "rust_cpu" => after[:rust_cpu] && before[:rust_cpu] && after[:rust_cpu] - before[:rust_cpu],
        "ruby_rss_kb" => rss_kb(Process.pid), "rust_rss_kb" => rss_kb(child.pid),
        "ruby_footprint_kb" => footprint_kb(Process.pid), "rust_footprint_kb" => footprint_kb(child.pid),
        "ruby_phases" => phase_delta(before[:phases], after[:phases]),
        "ruby_counters" => counter_delta(before[:counters], after[:counters]),
      }
    end

    def snapshot(child)
      report = Scarpe::Native::Stats.report
      {
        unix: unix_now, wall: monotonic,
        ruby_cpu: Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID),
        rust_cpu: cpu_seconds(child.pid),
        phases: report["phases"].transform_values(&:dup), counters: report["counters"].dup,
      }
    end

    def phase_delta(before, after)
      after.to_h do |name, tally|
        was = before[name] || { "n" => 0, "total_ms" => 0.0 }
        [name, { "n" => tally["n"] - was["n"], "total_ms" => tally["total_ms"] - was["total_ms"] }]
      end
    end

    def counter_delta(before, after)
      after.to_h { |name, value| [name, value - before.fetch(name, 0)] }
    end

    # Another process's CPU time so far, from ps ("1:02.50" is 62.5 s).
    def cpu_seconds(pid)
      text = `ps -o time= -p #{Integer(pid)}`.strip
      return nil if text.empty?

      text.split(":").map(&:to_f).reduce(0.0) { |total, part| total * 60 + part }
    end

    def rss_kb(pid)
      text = `ps -o rss= -p #{Integer(pid)}`.strip
      text.empty? ? nil : Integer(text)
    end

    # What Activity Monitor calls Memory: dirty and compressed pages, not shared framework pages.
    # macOS only (footprint(1)); nil elsewhere.
    def footprint_kb(pid)
      line = `footprint #{Integer(pid)} 2>/dev/null`[/phys_footprint:\s*([\d.]+)\s*([KMG]B)/]
      return nil unless line

      value, unit = Regexp.last_match(1).to_f, Regexp.last_match(2)
      (value * { "KB" => 1, "MB" => 1024, "GB" => 1024 * 1024 }.fetch(unit)).round
    end

    def write_report
      dir = ENV["SCARPE_NATIVE_STATS"] or return
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "driver.json"), JSON.generate(@report))
    end

    def automation
      Scarpe::Native::DisplayService.instance.automation
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def unix_now
      Process.clock_gettime(Process::CLOCK_REALTIME)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  app, action, *args = ARGV
  abort("usage: ruby drive.rb APP.rb run SECONDS | paced SECONDS | type KEYS | click TEXT TIMES") unless app && action
  Bench::Driver.new(app, action, args).run
end
