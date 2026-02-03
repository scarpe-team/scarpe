# frozen_string_literal: true

# Batch test legacy examples using Niente (headless display service)
# Tests that examples parse, load, and run their app block without crashing.
#
# Usage:
#   bundle exec ruby tasks/test_legacy_examples.rb [category]

require "fileutils"
require "tmpdir"

TIMEOUT_SECONDS = 5
EXAMPLE_DIR = File.expand_path("../examples/legacy/not_checked", __dir__)
SCARPE_EXE = File.expand_path("../exe/scarpe", __dir__)
PROJECT_DIR = File.expand_path("..", __dir__)

SKIP_PATTERNS = %w[chipmunk hpricot json/pure shoes/setup]

category = ARGV[0]

if category
  dirs = [File.join(EXAMPLE_DIR, category)]
  unless File.directory?(dirs[0])
    puts "Category #{category} not found"
    exit 1
  end
else
  dirs = Dir.glob("#{EXAMPLE_DIR}/*").select { |f| File.directory?(f) }
end

files = dirs.flat_map { |d| Dir.glob("#{d}/**/*.rb") }.sort
puts "Testing #{files.length} legacy examples with Niente (headless)..."
puts

pass = []
fail_list = []
skip_list = []

files.each do |file|
  relative = file.sub("#{EXAMPLE_DIR}/", "")

  # Check for known external deps
  content = File.read(file) rescue ""
  skip_reason = SKIP_PATTERNS.detect { |pat| content.include?(pat) }
  if skip_reason
    skip_list << [relative, "requires #{skip_reason}"]
    $stdout.write "\e[33mS\e[0m"
    $stdout.flush
    next
  end

  # Syntax check
  unless system("ruby", "-c", file, out: File::NULL, err: File::NULL)
    fail_list << [relative, "SYNTAX ERROR"]
    $stdout.write "\e[31mX\e[0m"
    $stdout.flush
    next
  end

  # Run with Niente — use timeout command and capture stderr to a temp file
  err_file = File.join(Dir.tmpdir, "scarpe_test_#{$$}.err")
  env_str = "SCARPE_DISPLAY_SERVICE=niente NIENTE_LOG_LEVEL=error LOCALAPPDATA=#{Dir.tmpdir}"
  cmd = "cd #{PROJECT_DIR} && #{env_str} timeout #{TIMEOUT_SECONDS} ruby #{SCARPE_EXE} --dev #{file} 2>#{err_file} >/dev/null"

  system(cmd)
  exit_code = $?.exitstatus

  if exit_code == 124 || exit_code == 0
    # 124 = timeout (app ran fine, just didn't exit) or 0 = clean exit
    pass << relative
    $stdout.write "\e[32m.\e[0m"
    $stdout.flush
  else
    # Read error output
    err_output = File.read(err_file) rescue ""
    err_lines = err_output.lines.reject { |l| l.include?("heartbeat") || l.include?("DisplayService debug") }
    err_msg = err_lines.detect { |l| l =~ /Error|undefined|uninitialized|wrong number/i }
    fail_list << [relative, (err_msg || "exit #{exit_code}").strip[0..120]]
    $stdout.write "\e[31mF\e[0m"
    $stdout.flush
  end

  File.delete(err_file) rescue nil
end

puts "\n\n#{"=" * 60}"
puts "RESULTS"
puts "=" * 60
puts "\e[32mPASS: #{pass.length}\e[0m"
puts "\e[31mFAIL: #{fail_list.length}\e[0m" unless fail_list.empty?
puts "\e[33mSKIP: #{skip_list.length}\e[0m" unless skip_list.empty?
puts "TOTAL: #{files.length}"

unless fail_list.empty?
  puts "\n--- Failures ---"
  fail_list.each { |f, err| puts "  #{f}: #{err}" }
end

unless skip_list.empty?
  puts "\n--- Skipped ---"
  skip_list.each { |f, reason| puts "  #{f}: #{reason}" }
end

# Save results
results_file = File.expand_path("../tmp/legacy_test_results.txt", __dir__)
FileUtils.mkdir_p(File.dirname(results_file))
File.open(results_file, "w") do |f|
  f.puts "Legacy Example Test Results — #{Time.now}"
  f.puts "=" * 60
  f.puts "PASS: #{pass.length} | FAIL: #{fail_list.length} | SKIP: #{skip_list.length} | TOTAL: #{files.length}"
  f.puts
  f.puts "--- PASS ---"
  pass.each { |p| f.puts "  #{p}" }
  f.puts
  f.puts "--- FAIL ---"
  fail_list.each { |fl, err| f.puts "  #{fl}: #{err}" }
  f.puts
  f.puts "--- SKIP ---"
  skip_list.each { |s, reason| f.puts "  #{s}: #{reason}" }
end
puts "\nResults saved to #{results_file}"
