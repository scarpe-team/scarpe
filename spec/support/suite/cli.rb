# frozen_string_literal: true

require "optparse"

module SpecSuite
  class CLI
    USAGE = <<~TEXT
      Usage: spec/run [options] [paths...]

      Runs .sspec cases (default: every case under spec/) against one display service, in
      parallel and sandboxed, writes spec/results/<display>.json and prints a scoreboard.
      Paths are files or directories, relative to the current directory or to spec/.
      With --examples, runs spec/examples.yml instead; paths then filter example paths.

      Exit status: 0 when nothing failed, 1 when a case failed, errored, timed out or
      passed against `expect: fail`, 2 for bad usage or (with --check) invalid cases.

    TEXT

    def self.start(argv)
      exit new(argv).run
    end

    def initialize(argv)
      @options = { display: ENV.fetch("SPEC_DISPLAY", "niente"), jobs: [Etc.nprocessors, 8].min, build: true }
      @paths = parser.parse(argv)
    rescue OptionParser::ParseError => e
      warn e.message, parser.help
      exit 2
    end

    def run
      unless DISPLAYS.include?(@options[:display])
        warn "spec/run: unknown display #{@options[:display].inspect} (#{DISPLAYS.join(", ")})"
        return 2
      end
      return check if @options[:check]

      NativeBinary.prepare(build: @options[:build]) if @options[:display] == "native"
      @options[:examples] ? run_examples : run_cases
    end

    private

    def parser
      @parser ||= OptionParser.new do |opts|
        opts.banner = USAGE
        opts.on("--display NAME", DISPLAYS, "niente (default) or native") { |value| @options[:display] = value }
        opts.on("-j", "--jobs N", Integer, "parallel processes (default #{@options[:jobs]})") { |value| @options[:jobs] = value }
        opts.on("--timeout SECS", Float, "per-case limit (default 20 niente, 40 native)") { |value| @options[:timeout] = value }
        opts.on("--examples", "smoke-run spec/examples.yml instead of cases") { @options[:examples] = true }
        opts.on("--wait SECS", Float, "examples: seconds to run each one (default 3 niente, 1.5 native)") { |value| @options[:wait] = value }
        opts.on("--include-skipped", "examples: also run entries whose status is skip") { @options[:include_skipped] = true }
        opts.on("--check", "only validate front matter and segments; run nothing") { @options[:check] = true }
        opts.on("--keep", "keep each sandbox and print where it is") { @options[:keep] = true }
        opts.on("--no-build", "native: do not cargo build before running") { @options[:build] = false }
        opts.on("-v", "--verbose", "print every row's message, not only failures") { @options[:verbose] = true }
        opts.on("-h", "--help") do
          puts opts.help
          exit 0
        end
      end
    end

    def display = @options[:display]

    def run_cases
      cases = case_files
      return no_input("no .sspec files under #{@paths.join(", ")}") if cases.empty?

      rows, secs = timed { in_sandboxes { |dir| Pool.map(cases, jobs: @options[:jobs]) { |file| run_case(file, dir) } } }
      results = ResultsFile.new(display, source_root: SPEC_DIR)
      results.merge(rows, display:)
      report(rows, "spec/run: #{cases.size} cases on #{display}, #{@options[:jobs]} jobs, #{secs}s", results.path)
    end

    def run_examples
      list = ExampleList.load
      if list.problems.any?
        warn list.problems
        return 2
      end
      examples = list.select(@paths.map { |path| SpecSuite.relative(path) })
      return no_input("no examples match #{@paths.join(", ")}") if examples.empty?

      rows, secs = timed do
        in_sandboxes do |dir|
          tree = ExampleTree.new(dir)
          Pool.map(examples, jobs: @options[:jobs]) { |example| run_example(example, tree, dir) }
        end
      end
      results = ResultsFile.new("examples-#{display}", source_root: REPO)
      results.merge(rows, display:)
      status = report(rows, "spec/run --examples: #{examples.size} examples on #{display}, #{@options[:jobs]} jobs, #{secs}s",
        results.path)
      puts "Gallery: #{SpecSuite.relative(Gallery.new.write)}"
      status
    end

    def run_case(file, dir)
      CaseRun.new(CaseFile.new(file), display:, sandboxes: dir, timeout: @options[:timeout], keep: @options[:keep]).call
    rescue StandardError => e
      { "path" => SpecSuite.relative(file), "status" => "error", "message" => "spec/run crashed: #{e.class}: #{e.message}" }
    end

    def run_example(example, tree, dir)
      ExampleRun.new(example, display:, tree:, sandboxes: dir, wait: @options[:wait],
        include_skipped: @options[:include_skipped], keep: @options[:keep]).call
    rescue StandardError => e
      { "path" => example.path, "status" => "error", "message" => "spec/run crashed: #{e.class}: #{e.message}" }
    end

    def check
      cases = case_files
      invalid = cases.map { |file| CaseFile.new(file) }.reject(&:valid?)
      invalid.each { |bad| puts "#{bad.relative_path}: #{bad.problems.join("; ")}" }
      puts "#{cases.size - invalid.size}/#{cases.size} cases valid"
      invalid.empty? ? 0 : 2
    end

    def report(rows, title, results_path)
      puts
      scoreboard = Scoreboard.new(rows, title:, results_path:, verbose: @options[:verbose])
      scoreboard.print
      scoreboard.bad? ? 1 : 0
    end

    def case_files
      roots = @paths.empty? ? [SPEC_DIR] : @paths.map { |path| resolve(path) }
      roots.flat_map do |root|
        File.directory?(root) ? Dir.glob(File.join(root, "**", "*.sspec")) : [root]
      end.reject { |path| path.start_with?(RESULTS_DIR + "/") }.uniq.sort
    end

    def resolve(path)
      candidates = [File.expand_path(path), File.expand_path(path, SPEC_DIR), File.expand_path(path, REPO)]
      found = candidates.find { |candidate| File.exist?(candidate) }
      return found if found

      warn "spec/run: no such file or directory: #{path}"
      exit 2
    end

    def in_sandboxes
      dir = Dir.mktmpdir("scarpe-spec-")
      yield dir
    ensure
      FileUtils.rm_rf(dir) if dir && !@options[:keep]
    end

    def timed
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      [result, (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)]
    end

    def no_input(message)
      warn "spec/run: #{message}"
      2
    end
  end
end
