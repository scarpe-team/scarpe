# frozen_string_literal: false
require 'diff/lcs'
require 'diff/lcs/hunk'
require 'fileutils'
require "htmlbeautifier"

puts "== Checking HTML fixtures =="


# Get top-level Ruby examples
file_paths = Dir["examples/*.rb"]

# Get each filename, or one if supplied as argument
file_names = if ENV['SELECTED_FILE']
  [ENV['SELECTED_FILE']]
else
  file_paths.map do |file|
    File.basename(file) # Exclude the file extension
  end
end

collection_of_html = []
any_failures = false
failures = []

# ASCII color and format codes
red = "\e[31m"
green = "\e[32m"
bold = "\e[1m"
reset = "\e[0m"

def diff_as_string(data_new, data_old, file_name)
  data_old = data_old.split(/\n/).map! { |e| e.chomp }
  data_new = data_new.split(/\n/).map! { |e| e.chomp }

  diffs = Diff::LCS.diff(data_old, data_new)
  return if diffs.empty?

  context_lines = 1

  oldhunk = hunk = nil
  file_length_difference = 0

  output = ""
  diffs.each do |piece|
    begin
      hunk = Diff::LCS::Hunk.new(data_old, data_new, piece,
                context_lines,
                file_length_difference
                )
      file_length_difference = hunk.file_length_difference

      next unless oldhunk

      # Hunks may overlap, which is why we need to be careful when our
      # diff includes lines of context. Otherwise, we might print
      # redundant lines.
      if (context_lines > 0) and hunk.overlaps?(oldhunk)
        hunk.unshift(oldhunk)
      else
        output << oldhunk.diff(:unified, "#{file_name}:") << "\n"
      end
    ensure
      oldhunk = hunk
    end
  end

  #Handle the last remaining hunk
  output << oldhunk.diff(:unified, "#{file_name}:") << "\n"
end

file_names.each do |file_name|
  # Read the entire file

  content = File.read(File.join(File.expand_path("../examples", __dir__),"#{file_name}"))
 

  # Skip this file if it contains the magic comment
  next if content.include?("# html_ci: false")

  output = ""
  pid = nil
  command = "bundle exec ./exe/scarpe examples/#{file_name} --dev --debug"

  IO.popen(command) do |io|
    pid = io.pid # captures the pid of the child process
    io.each_line do |line|
      output << line
      if line.include?(":heartbeat")
        Process.kill("SIGKILL", pid)
        break
      end
    end
  end

  def match_output(logs)
    logs.match(/(?<=code_string = ").*(?=")/)[0].split("`")[1]
  end

  def format_html(html)
    html.gsub!(/\\/, "") # Remove all backslashes
    html
  end

  html = format_html(
    match_output(output),
  )
  # puts formatted_html
  pretty_html = HtmlBeautifier.beautify(html)

  # Compare to fixture
  dir_path = "test/wv/html_fixtures"
  begin
  file_path = "#{dir_path}/#{file_name.split(".")[0]}.html"

  expected_output = File.read(file_path)
  rescue => e
    raise "Hey, you need to regenerate fixtures, do this using command 'rake test:regenerate_html_fixtures' "
  end

  # Do the comparison
  # diff = Diff::LCS.diff(pretty_html, expected_output)
  diff_output = diff_as_string(pretty_html, expected_output, file_name)

  if diff_output.nil?
    puts "#{green}#{bold}PASSED#{reset}: #{file_name}"
  else
    puts "#{red}#{bold}FAILED#{reset}: #{file_name}\nDiff:"
    puts diff_output
    print reset
    failures << file_name  # Add name of failed file to the array
  end
end

unless failures.empty?
  puts "\n=== #{bold}Summary#{reset} ==="
  puts "The following files have had their HTML output change with your changes"
  puts "This may indicate an error. Please check the diff and update the fixture if necessary."
  puts "You can update the fixture by running #{bold}`rake test:regenerate_html_fixtures`#{reset}\n\n"
  failures.each do |file|
    puts "#{red}#{file}#{reset}"
  end
  exit 1
end
puts "== Completed HTML fixture check =="
