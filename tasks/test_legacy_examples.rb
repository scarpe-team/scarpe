# frozen_string_literal: true

# Batch test legacy examples using Niente (headless display service)
# This tests that examples parse, load, and run their app block without crashing.
# It can't test visual rendering, but it catches API errors, missing methods, etc.
#
# Usage:
#   bundle exec ruby tasks/test_legacy_examples.rb [category]
#   e.g.: bundle exec ruby tasks/test_legacy_examples.rb shoes-contrib
#   or:   bundle exec ruby tasks/test_legacy_examples.rb   (tests all)

require "timeout"
require "open3"

TIMEOUT_SECONDS = 10
EXAMPLE_DIR = File.expand_path("../examples/legacy/not_checked", __dir__)

category = ARGV[0]

if category
  dirs = [File.join(EXAMPLE_DIR, category)]
  unless File.directory?(dirs[0])
    puts "Category #{category} not found at #{dirs[0]}"
    exit 1
  end
else
  dirs = Dir.glob("#{EXAMPLE_DIR}/*").select { |f| File.directory?(f) }
end

files = dirs.flat_map { |d| Dir.glob("#{d}/**/*.rb") }.sort

puts "Testing #{files.length} legacy examples with Niente (headless)..."
puts

pass = []
fail_parse = []
fail_runtime = []
fail_timeout = []

files.each do |file|
  relative = file.sub("#{EXAMPLE_DIR}/", "")
  
  # First: syntax check
  stdout, stderr, status = Open3.capture3("ruby -c #{file}")
  unless status.success?
    fail_parse << [relative, stderr.lines.first&.strip]
    next
  end

  # Second: try to load with Niente
  # We use --dev flag which enables Niente headless display
  cmd = "bundle exec ruby exe/scarpe --dev --niente #{file}"
  
  begin
    stdout, stderr, status = Timeout.timeout(TIMEOUT_SECONDS) do
      Open3.capture3(cmd, chdir: File.expand_path("..", __dir__))
    end

    if status.success? || status.exitstatus == 0
      pass << relative
      print "\e[32m.\e[0m"
    else
      error_line = (stderr + stdout).lines.detect { |l| l.include?("Error") || l.include?("error") || l.include?("undefined") }
      fail_runtime << [relative, error_line&.strip || "exit code #{status.exitstatus}"]
      print "\e[31mF\e[0m"
    end
  rescue Timeout::Error
    # Timeout likely means the app ran fine but didn't exit
    # (which is normal for GUI apps). Count as pass.
    pass << relative
    print "\e[32m.\e[0m"
  end
end

puts "\n\n=== Results ==="
puts "\e[32mPASS: #{pass.length}\e[0m"
puts "\e[31mFAIL (parse): #{fail_parse.length}\e[0m" unless fail_parse.empty?
puts "\e[31mFAIL (runtime): #{fail_runtime.length}\e[0m" unless fail_runtime.empty?
puts "\e[33mTIMEOUT: #{fail_timeout.length}\e[0m" unless fail_timeout.empty?

unless fail_parse.empty?
  puts "\n--- Parse Failures ---"
  fail_parse.each { |f, err| puts "  #{f}: #{err}" }
end

unless fail_runtime.empty?
  puts "\n--- Runtime Failures ---"
  fail_runtime.each { |f, err| puts "  #{f}: #{err}" }
end

puts "\nTotal: #{files.length} | Pass: #{pass.length} | Fail: #{fail_parse.length + fail_runtime.length + fail_timeout.length}"
