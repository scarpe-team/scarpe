# frozen_string_literal: true

require "fileutils"
require "monitor"
require "open3"
require "shellwords"

module Scarpe::Native
  class ChildDied < Scarpe::Error; end
  class ChildNotFound < Scarpe::Error; end
  class ChildTimeout < Scarpe::Error; end

  # Where the Ruby side's time goes, for native/PERF.md. Off unless SCARPE_NATIVE_STATS names a
  # directory; the pump then writes <dir>/ruby.json when it stops (Rust writes rust.json beside it).
  module Stats
    extend self

    def enabled?
      return @enabled if defined?(@enabled)

      @enabled = !ENV["SCARPE_NATIVE_STATS"].to_s.empty?
    end

    # Adds the block's wall time to phase. Phases can nest (encode happens inside timers).
    def time(phase)
      return yield unless enabled?

      started = monotonic
      begin
        yield
      ensure
        add(phase, monotonic - started)
      end
    end

    def add(phase, seconds)
      tally = (phases[phase] ||= { "n" => 0, "total_ms" => 0.0, "max_ms" => 0.0 })
      ms = seconds * 1000.0
      tally["n"] += 1
      tally["total_ms"] += ms
      tally["max_ms"] = ms if ms > tally["max_ms"]
    end

    def count(name, by = 1)
      counters[name] = counters.fetch(name, 0) + by if enabled?
    end

    # A milestone, in Unix seconds so it lines up with Rust's rust.json. First time only.
    def mark(name)
      marks[name] ||= Process.clock_gettime(Process::CLOCK_REALTIME) if enabled?
    end

    def write
      return unless enabled?

      dir = ENV["SCARPE_NATIVE_STATS"]
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "ruby.json"), JSON.generate(report))
    end

    # Forgets everything, and whether it is on (tests flip SCARPE_NATIVE_STATS).
    def reset!
      remove_instance_variable(:@enabled) if defined?(@enabled)
      @phases = @counters = @marks = nil
    end

    def report
      times = Process.times
      {
        "pid" => Process.pid, "ruby" => RUBY_VERSION, "yjit" => yjit?,
        "marks" => marks, "phases" => phases, "counters" => counters,
        "cpu" => { "ruby" => times.utime + times.stime, "children" => times.cutime + times.cstime },
      }
    end

    private

    def yjit?
      defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? true : false
    end

    def phases = (@phases ||= {})
    def counters = (@counters ||= {})
    def marks = (@marks ||= {})

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  # Finds the scarpe-native binary, building it first in a dev checkout when it is missing or stale.
  module Binary
    extend self

    CRATE = File.join(ROOT, "native")
    DEV_BINARY = File.join(CRATE, "target", "release", "scarpe-native")

    def path
      explicit = ENV["SCARPE_NATIVE_BIN"].to_s
      return explicit unless explicit.empty?
      return dev_binary if File.exist?(File.join(CRATE, "Cargo.toml"))

      packaged_binary || raise(ChildNotFound, "Can't find the scarpe-native binary. Set SCARPE_NATIVE_BIN to its path.")
    end

    def dev_binary
      build if stale?
      DEV_BINARY
    end

    def stale?(binary: DEV_BINARY, crate: CRATE)
      return true unless File.exist?(binary)

      built_at = File.mtime(binary)
      sources(crate).any? { |source| File.mtime(source) > built_at }
    end

    def sources(crate)
      manifests = %w[Cargo.toml Cargo.lock].map { |name| File.join(crate, name) }
      Dir[File.join(crate, "src", "**", "*")].select { |f| File.file?(f) } + manifests.select { |f| File.exist?(f) }
    end

    def build
      $stderr.puts("scarpe-native: building #{CRATE} (cargo build --release)")
      unless system(cargo, "build", "--release", chdir: CRATE, out: :err)
        raise ChildNotFound, "cargo build --release failed in #{CRATE}"
      end

      # Cargo leaves the binary alone when nothing it tracks changed; touching it stops us rebuilding every launch.
      FileUtils.touch(DEV_BINARY)
    end

    def cargo
      ENV["CARGO"] || which("cargo") || File.expand_path("~/.cargo/bin/cargo")
    end

    def packaged_binary
      beside_script = File.dirname(File.expand_path($PROGRAM_NAME))
      candidates = [beside_script, File.expand_path("../MacOS", beside_script)].map { |dir| File.join(dir, "scarpe-native") }
      candidates.find { |candidate| File.executable?(candidate) } || which("scarpe-native")
    end

    def which(name)
      ENV["PATH"].to_s.split(File::PATH_SEPARATOR).map { |dir| File.join(dir, name) }.find { |f| File.executable?(f) && File.file?(f) }
    end
  end

  # The Rust child process and its NDJSON pipe (DESIGN section 4).
  #
  # Outgoing messages are buffered until #flush (or a request). Incoming lines are sorted into
  # replies (picked up by whoever made the request) and everything else (the inbox, drained by the pump).
  # Writes are guarded by a Mutex because download callbacks run on other threads; reads by a Monitor,
  # held only for one short IO.select at a time so waiting threads interleave.
  class Child
    PROTOCOL_VERSION = 1
    STDERR_TAIL_LINES = 40
    READY_TIMEOUT = 20.0
    POLL = 0.05

    attr_reader :pid

    def self.start(headless: false)
      args = []
      args << "--headless" if headless
      args.concat(Shellwords.split(ENV["SCARPE_NATIVE_ARGS"].to_s))
      new([Binary.path, *args])
    end

    def initialize(command, ready_timeout: READY_TIMEOUT)
      @log = Shoes::Log.logger("Scarpe::Native::Child")
      @trace = !ENV["SCARPE_NATIVE_TRACE"].to_s.empty?
      @ready_timeout = ready_timeout
      Stats.mark("spawn")
      @spawned_at = monotonic
      @stdin, @stdout, @stderr, @wait_thread = spawn(command)
      @pid = @wait_thread.pid
      [@stdin, @stdout].each(&:binmode)

      @outbox = []
      @write_lock = Mutex.new
      @read_lock = Monitor.new
      @read_buffer = String.new(encoding: Encoding::BINARY)
      @inbox = []
      @replies = {}
      @next_req = 0
      @eof = false

      @stderr_tail = []
      @stderr_lock = Mutex.new
      @stderr_thread = Thread.new { drain_stderr }

      say_hello
    end

    # Rust's version, from its answer to hello (waiting for it, the first time).
    def version
      ready["version"]
    end

    # A child that has not answered hello by now is stuck starting up: say so instead of waiting on.
    def check_started!
      return if @ready || @eof || monotonic - @spawned_at < @ready_timeout

      raise ChildTimeout, "scarpe-native did not answer hello within #{@ready_timeout}s"
    end

    def post(message)
      line = Stats.time(:encode) { encode(message) }
      @write_lock.synchronize { @outbox << line } if line
    end

    # Ends a batch: Rust applies everything, lays out and paints once.
    def flush
      @write_lock.synchronize do
        next if @outbox.empty?

        @outbox << encode(t: "flush")
        Stats.count("flushes")
        write_outbox
      end
    end

    # Sends a req and blocks until its reply. Rust flushes implicitly before a req, and writes every
    # event the req causes before the reply, so those events are in the inbox when this returns.
    def request(op, timeout: nil, **fields)
      id = @write_lock.synchronize do
        @next_req += 1
        @outbox << (encode(t: "req", req: @next_req, op: op.to_s, **fields) || raise(ArgumentError, "unencodable #{op} request"))
        write_outbox
        @next_req
      end
      await("a reply to req #{op}", timeout: timeout) { @replies.delete(id) }
    end

    def messages
      @read_lock.synchronize do
        out = @inbox
        @inbox = []
        out
      end
    end

    def pending?
      !@inbox.empty?
    end

    # Waits up to timeout for input, reading whatever arrives into the inbox.
    def wait_for_input(timeout)
      @read_lock.synchronize { read_some(pending? ? 0 : timeout) }
    end

    # Gone once its stdout ends, not when the process ends: the last lines it wrote (a "closed",
    # say) may still be waiting in the pipe.
    def dead?
      @eof
    end

    def exit_status
      @wait_thread.join(1) && @wait_thread.value
    end

    def death_report
      status = exit_status
      how = if status.nil? then "is not answering"
      elsif status.signaled? then "was killed by signal #{status.termsig}"
      else "exited with status #{status.exitstatus}"
      end
      @stderr_thread.join(1)
      tail = @stderr_lock.synchronize { @stderr_tail.join }
      message = "scarpe-native (pid #{@pid}) #{how}."
      tail.empty? ? message : "#{message} The end of its stderr:\n#{tail}"
    end

    # Closing stdin tells Rust to exit; it gets a moment before we insist.
    def close(grace: 2.0)
      return if @closed

      @closed = true
      @write_lock.synchronize do
        write_outbox
        @stdin.close unless @stdin.closed?
      end
      return if @wait_thread.join(grace)

      signal("TERM")
      signal("KILL") unless @wait_thread.join(1)
    rescue IOError, SystemCallError
      nil
    end

    private

    # Its own process group, so a terminal Ctrl-C reaches Ruby (which quits the child) and not the child.
    def spawn(command)
      Open3.popen3(*command, pgroup: true)
    rescue SystemCallError => e
      raise ChildNotFound, "Can't start #{command.first}: #{e.message}"
    end

    # Hello goes out without waiting for the answer, so Ruby builds the app while Rust starts up
    # (loading fonts, opening its event loop). Rust answers in order, so nothing needs the answer first.
    def say_hello
      post(t: "hello", v: PROTOCOL_VERSION, pid: Process.pid)
      @write_lock.synchronize { write_outbox }
    end

    def ready
      @ready || await("the ready handshake", timeout: @ready_timeout) { @ready }
    end

    def note_ready(message)
      @ready = message
      Stats.mark("ready")
      @log.warn("scarpe-native speaks protocol #{message["v"].inspect}, we speak #{PROTOCOL_VERSION}") if message["v"] != PROTOCOL_VERSION
    end

    def await(what, timeout: nil)
      deadline = timeout && monotonic + timeout
      loop do
        @read_lock.synchronize do
          found = yield
          return found if found
          raise ChildDied, "#{death_report} (while waiting for #{what})" if @eof

          read_some(deadline ? (deadline - monotonic).clamp(0, POLL) : POLL)
        end
        raise ChildTimeout, "scarpe-native did not send #{what} within #{timeout}s" if deadline && monotonic > deadline
      end
    end

    def read_some(timeout)
      return if @eof
      return unless IO.select([@stdout], nil, nil, timeout)

      chunk = @stdout.read_nonblock(65_536, exception: false)
      return if chunk == :wait_readable
      return @eof = true if chunk.nil?

      @read_buffer << chunk
      while (newline = @read_buffer.index("\n"))
        accept(@read_buffer.slice!(0..newline))
      end
    rescue IOError, SystemCallError
      @eof = true
    end

    def accept(line)
      line = line.force_encoding(Encoding::UTF_8).strip
      return if line.empty?

      $stderr.puts("scarpe-native <- #{line}") if @trace
      message = Stats.time(:parse) { JSON.parse(line) }
      case message["t"]
      when "reply" then @replies[message["req"]] = message
      when "ready" then note_ready(message)
      else @inbox << message
      end
    rescue JSON::ParserError
      @log.warn("Ignoring a line from scarpe-native that is not JSON: #{line[0, 200].inspect}")
    end

    def encode(message)
      JSON.generate(message)
    rescue JSON::GeneratorError => e
      @log.error("Could not encode #{message.inspect[0, 300]} for scarpe-native: #{e.message}")
      nil
    end

    # Callers hold @write_lock.
    def write_outbox
      return if @outbox.empty?

      lines = @outbox
      @outbox = []
      lines.each { |line| $stderr.puts("scarpe-native -> #{line}") } if @trace
      Stats.time(:write) do
        chunk = lines.join("\n") << "\n"
        Stats.count("lines", lines.size)
        Stats.count("bytes", chunk.bytesize)
        @stdin.write(chunk)
        @stdin.flush
      end
    rescue IOError, SystemCallError
      # The child is gone; the reader sees EOF and reports it.
      nil
    end

    def drain_stderr
      @stderr.each_line do |line|
        $stderr.write(line)
        @stderr_lock.synchronize do
          @stderr_tail << line
          @stderr_tail.shift while @stderr_tail.size > STDERR_TAIL_LINES
        end
      end
    rescue IOError, SystemCallError
      nil
    end

    def signal(name)
      Process.kill(name, @pid)
    rescue SystemCallError
      nil
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
