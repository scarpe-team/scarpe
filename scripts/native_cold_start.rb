#!/usr/bin/env ruby
# frozen_string_literal: true

# Cold start to first frame for a natively packaged app (docs/native_packaging.md).
#
#   ruby scripts/native_cold_start.rb APP.rb [--runs 5] [--out DIR] [--windowed] [--snapshot PNG]
#                                            [--dev-ruby RUBY]
#
# Packages a copy of APP.rb (the app itself is untouched) with a probe appended that waits for the
# first painted frame, prints the time and quits. Then runs Contents/MacOS/scarpe-launcher RUNS
# times per variant, headless unless --windowed (ghost windows: real frames, but invisible,
# click-through and never taking focus), and prints the median milliseconds from exec to the
# first frame:
#
#   bytecode + YJIT       the default launch (YJIT comes on after the first frame, if the Ruby has it)
#   no bytecode           SCARPE_BYTECODE=0
#   bytecode, no YJIT     RUBY_YJIT_ENABLE=0 (the same as the default when the Ruby has no YJIT)
#
# --dev-ruby RUBY adds rows for the bundle's boot.rb run by RUBY instead (from source, since the
# bytecode belongs to the bundled Ruby), with YJIT late, at start (RUBY_YJIT_ENABLE=1) and off.
#
# "Cold" here means a new process each time; the disk cache is warm after the first run.

require "fileutils"
require "json"
require "optparse"
require "rbconfig"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)

PROBE = File.read(File.join(__dir__, "native_first_frame_probe.rb"))

VARIANTS = {
  "bytecode + YJIT" => {},
  "no bytecode" => { "SCARPE_BYTECODE" => "0" },
  "bytecode, no YJIT" => { "RUBY_YJIT_ENABLE" => "0" },
}.freeze

options = { runs: 5, out: File.join(Dir.tmpdir, "scarpe-cold-start"), windowed: false }
OptionParser.new do |o|
  o.banner = "usage: ruby scripts/native_cold_start.rb APP.rb [options]"
  o.on("--runs N", Integer) { |n| options[:runs] = n }
  o.on("--out DIR") { |dir| options[:out] = File.expand_path(dir) }
  o.on("--windowed", "ghost windows instead of headless") { options[:windowed] = true }
  o.on("--snapshot PNG", "save the first frame of the first run") { |png| options[:snapshot] = File.expand_path(png) }
  o.on("--dev-ruby RUBY", "also time the bundle's boot.rb run by this Ruby, YJIT late, early and off") { |ruby| options[:dev_ruby] = ruby }
end.parse!
app = File.expand_path(ARGV.fetch(0) { abort "usage: ruby scripts/native_cold_start.rb APP.rb [--runs 5]" })

def package(app, out)
  FileUtils.mkdir_p(out)
  probe_app = File.join(out, "probe", File.basename(app))
  FileUtils.mkdir_p(File.dirname(probe_app))
  File.write(probe_app, File.read(app) + PROBE)
  command = [RbConfig.ruby, File.join(ROOT, "exe", "scarpe"), "package", probe_app, "--native", "--name", "Probe", "--output", out, "--install-dir", out]
  system(*command, out: File::NULL) || abort("packaging failed: #{command.join(" ")}")
  File.join(out, "Probe.app")
end

# Milliseconds from exec to the probe's first frame, plus what the probe saw.
def launch(command, env, windowed:)
  env = { "HOME" => Dir.home, "PATH" => "/usr/bin:/bin", "SCARPE_NATIVE_GHOST" => "1" }.merge(env)
  env["SCARPE_NATIVE_HEADLESS"] = "1" unless windowed
  reader, writer = IO.pipe
  started = Process.clock_gettime(Process::CLOCK_REALTIME)
  pid = Process.spawn(env, *command, err: writer, out: File::NULL, unsetenv_others: true)
  writer.close
  watchdog = Thread.new do
    sleep(60)
    Process.kill("KILL", pid)
  end
  stderr = reader.read
  Process.wait(pid)
  watchdog.kill
  probe = stderr[/^scarpe-probe (.*)$/, 1] or abort("no first frame (exit #{$?.exitstatus}):\n#{stderr}")
  report = JSON.parse(probe)
  report.merge("ms" => ((report["at"] - started) * 1000).round(1), "exit" => $?.exitstatus)
end

def median(values)
  sorted = values.sort
  sorted[sorted.size / 2]
end

# Runs every variant once per round, so drift in the machine's load spreads over all of them.
def measure(variants, options)
  runs = Hash.new { |hash, label| hash[label] = [] }
  options[:runs].times do
    variants.each { |label, command, env| runs[label] << launch(command, env, windowed: options[:windowed]) }
  end
  runs.each do |label, results|
    last = results.last
    puts format("  %-26s %7.1f ms   runs %s   bytecode hits %s, YJIT %s, Ruby %s, exits %s",
      label, median(results.map { |run| run["ms"] }), results.map { |run| run["ms"].round }.inspect,
      last["bytecode_hits"].inspect, last["yjit"], last["ruby"], results.map { |run| run["exit"] }.uniq.inspect)
  end
end

bundle = package(app, options[:out])
launcher = [File.join(bundle, "Contents", "MacOS", "scarpe-launcher")]
puts "#{File.basename(app)} packaged as #{bundle}"
puts "#{options[:runs]} rounds, #{options[:windowed] ? "windowed (ghost)" : "headless"}, median ms from exec to first frame"
puts "load average #{`sysctl -n vm.loadavg`.strip} (a busy machine moves these numbers by tens of ms)"

if options[:snapshot]
  shot = launch(launcher, { "SCARPE_PROBE_SNAPSHOT" => options[:snapshot] }, windowed: options[:windowed])
  puts "snapshot #{options[:snapshot]} (#{shot["frames"]} frames painted, exit #{shot["exit"]})"
end

variants = VARIANTS.map { |label, env| [label, launcher, env] }

# The bundle's boot.rb run by another Ruby (one built with YJIT, say). The bytecode belongs to the
# bundled Ruby, so this Ruby loads everything from source.
if options[:dev_ruby]
  resources = File.join(bundle, "Contents", "Resources")
  command = [options[:dev_ruby], File.join(resources, "boot.rb"), File.basename(app)]
  env = {
    "RUBYLIB" => %w[lib lacci/lib scarpe-components/lib].map { |dir| File.join(resources, "scarpe", dir) }.join(":"),
    "SCARPE_NATIVE_BIN" => File.join(bundle, "Contents", "MacOS", "scarpe-native"),
  }
  variants << ["other Ruby, YJIT late", command, env]
  variants << ["other Ruby, YJIT at start", command, env.merge("RUBY_YJIT_ENABLE" => "1")]
  variants << ["other Ruby, no YJIT", command, env.merge("RUBY_YJIT_ENABLE" => "0")]
  puts "other Ruby: #{options[:dev_ruby]} running the bundle's boot.rb"
end

measure(variants, options)
