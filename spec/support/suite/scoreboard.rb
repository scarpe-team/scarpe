# frozen_string_literal: true

module SpecSuite
  # The human-readable report: one line per directory, then every row that needs attention.
  class Scoreboard
    COLUMNS = {
      "pass" => "pass", "fail" => "fail", "error" => "error", "skip" => "skip", "expected_fail" => "xfail",
      "unexpected_pass" => "xpass", "not_applicable" => "n/a", "timeout" => "timeout",
    }.freeze
    PROGRESS = {
      "pass" => ".", "fail" => "F", "error" => "E", "skip" => "S", "expected_fail" => "x",
      "unexpected_pass" => "X", "not_applicable" => "-", "timeout" => "T",
    }.freeze

    def self.progress(row) = PROGRESS.fetch(row["status"], "?")

    def initialize(rows, title:, results_path:, verbose: false)
      @rows = rows.sort_by { |row| row["path"] }
      @title = title
      @results_path = results_path
      @verbose = verbose
    end

    def print(io = $stdout)
      io.puts
      io.puts @title
      io.puts
      print_table(io)
      print_attention(io)
      io.puts
      io.puts "Results: #{SpecSuite.relative(@results_path)}"
    end

    def bad?
      @rows.any? { |row| BAD_STATUSES.include?(row["status"]) }
    end

    private

    def print_table(io)
      groups = @rows.group_by { |row| File.dirname(row["path"]) }
      width = [groups.keys.map(&:length).max.to_i, "directory".length].max
      io.puts format_line("directory", COLUMNS.values, width)
      groups.sort.each do |dir, rows|
        io.puts format_line(dir, counts_for(rows), width)
      end
      io.puts format_line("total (#{@rows.size})", counts_for(@rows), width)
    end

    def counts_for(rows)
      tally = rows.map { |row| row["status"] }.tally
      COLUMNS.keys.map { |status| tally[status] ? tally[status].to_s : "." }
    end

    def format_line(label, cells, width)
      label.ljust(width) + "  " + cells.map { |cell| cell.rjust(8) }.join
    end

    def print_attention(io)
      shown = @rows.select { |row| BAD_STATUSES.include?(row["status"]) || (@verbose && row["message"]) }
      return if shown.empty?

      io.puts
      shown.each do |row|
        io.puts "#{row["status"].upcase.ljust(15)} #{row["path"]}"
        io.puts "                #{row["message"].to_s.gsub("\n", "\n                ")}" if row["message"]
        io.puts "                sandbox kept at #{row["sandbox"]}" if row["sandbox"]
      end
    end
  end
end
