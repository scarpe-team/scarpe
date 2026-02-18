#!/usr/bin/env ruby
# frozen_string_literal: true

# Captures HTML output from a Scarpe app for visual inspection
# Usage: ruby tasks/capture_html.rb examples/legacy/working/simple/calc.rb

require 'fileutils'

file_path = ARGV[0]
unless file_path
  puts "Usage: ruby tasks/capture_html.rb <path_to_app.rb>"
  exit 1
end

output = ""
command = "bundle exec ./exe/scarpe #{file_path} --dev --debug 2>&1"

IO.popen(command) do |io|
  pid = io.pid
  io.each_line do |line|
    output << line
    if line.include?(":heartbeat") || line.include?("innerHTML")
      Process.kill("SIGKILL", pid) rescue nil
      break
    end
  end
end

# Extract innerHTML from debug output
match = output.match(/innerHTML = `([^`]+)`/)
unless match
  puts "ERROR: Could not find innerHTML in output"
  puts output.lines.last(20).join
  exit 1
end

html_content = match[1].gsub(/\\\"/, '"').gsub(/\\\\/, '\\')

# Wrap in full HTML document
full_html = <<~HTML
<!DOCTYPE html>
<html>
<head>
  <title>Scarpe Preview: #{File.basename(file_path)}</title>
  <style>
    body {
      font-family: arial, Helvetica, sans-serif;
      margin: 0;
      padding: 20px;
      background: #f5f5f5;
    }
    #preview {
      background: white;
      border: 1px solid #ccc;
      padding: 10px;
      min-height: 300px;
    }
    h1 { font-size: 14px; color: #666; }
  </style>
</head>
<body>
  <h1>Preview: #{File.basename(file_path)}</h1>
  <div id="preview">
    #{html_content}
  </div>
</body>
</html>
HTML

# Save to temp file
output_path = "/tmp/scarpe_preview.html"
File.write(output_path, full_html)
puts "Saved preview to: #{output_path}"
puts "HTML size: #{html_content.length} bytes"
