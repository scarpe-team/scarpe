# frozen_string_literal: true

module SpecSuite
  # spec/results/<display>.json (cases) and spec/results/examples-<display>.json (examples).
  #
  # Each run merges its rows into the file, so six lanes validating their own directories
  # build up one picture instead of clobbering each other. Rows for files that no longer
  # exist are dropped. A lock file serialises concurrent writers.
  class ResultsFile
    attr_reader :path

    def initialize(name, source_root:)
      @path = File.join(RESULTS_DIR, "#{name}.json")
      @source_root = source_root
    end

    def merge(rows, display:)
      FileUtils.mkdir_p(RESULTS_DIR)
      File.open("#{path}.lock", File::RDWR | File::CREAT) do |lock|
        lock.flock(File::LOCK_EX)
        entries = existing_entries.select { |key, _| File.exist?(File.join(@source_root, key)) }
        stamp = Time.now.utc.iso8601
        rows.reject { |row| row["path"].start_with?("/") }.each do |row|
          entries[row["path"]] = row.except("path").merge("run_at" => stamp)
        end
        write(display, entries.sort.to_h)
      end
    end

    private

    def existing_entries
      data = File.exist?(path) ? JSON.parse(File.read(path)) : {}
      data.is_a?(Hash) ? data.fetch("results", {}) : {}
    rescue JSON::ParserError
      {}
    end

    def write(display, entries)
      counts = entries.values.map { |entry| entry["status"] }.tally
      document = {
        "display" => display,
        "updated_at" => Time.now.utc.iso8601,
        "counts" => STATUSES.to_h { |status| [status, counts.fetch(status, 0)] },
        "results" => entries,
      }
      temp = "#{path}.#{Process.pid}.tmp"
      File.write(temp, JSON.pretty_generate(document) + "\n")
      File.rename(temp, path)
    end
  end
end
