# frozen_string_literal: true

require "fileutils"
require "monitor"
require "open3"
require "rbconfig"
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

  # Finds the scarpe-native binary: SCARPE_NATIVE_BIN, a packaged app's own, one on PATH, or in a
  # git checkout of Scarpe a dev build, built first when it is missing or stale. An installed gem
  # ships the crate too, but a gem directory is no place to run cargo at an app's launch.
  module Binary
    extend self

    # ".exe" on Windows, where cargo names the binary scarpe-native.exe; "" elsewhere.
    EXE = RbConfig::CONFIG["EXEEXT"].to_s
    CRATE = File.join(ROOT, "native")
    DEV_BINARY = File.join(CRATE, "target", "release", "scarpe-native#{EXE}")

    def path
      explicit = ENV["SCARPE_NATIVE_BIN"].to_s
      return explicit unless explicit.empty?

      packaged_binary || which("scarpe-native") || (dev_binary if checkout?) ||
        raise(ChildNotFound, "Can't find the scarpe-native binary. Set SCARPE_NATIVE_BIN to its path.")
    end

    # A worktree's .git is a file, a clone's a directory; an installed gem has neither.
    def checkout?(root: ROOT)
      File.exist?(File.join(root, ".git")) && File.exist?(File.join(root, "native", "Cargo.toml"))
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
      ENV["CARGO"] || which("cargo") || File.expand_path("~/.cargo/bin/cargo#{EXE}")
    end

    def packaged_binary
      beside_script = File.dirname(File.expand_path($PROGRAM_NAME))
      candidates = [beside_script, File.expand_path("../MacOS", beside_script)].map { |dir| File.join(dir, "scarpe-native#{EXE}") }
      candidates.find { |candidate| File.executable?(candidate) }
    end

    def which(name)
      ENV["PATH"].to_s.split(File::PATH_SEPARATOR).map { |dir| File.join(dir, "#{name}#{EXE}") }.find { |f| File.executable?(f) && File.file?(f) }
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
    OWN_GROUP = Gem.win_platform? ? { new_pgroup: true } : { pgroup: true }
    STDERR_TAIL_LINES = 40
    READY_TIMEOUT = 20.0
    POLL = 0.05
    # On Windows IO.select can only poll a pipe, about every 10 ms, which a test that reads a few
    # thousand pixels one req at a time pays on every reply. There a thread does blocking reads,
    # which return as soon as Rust writes, and hands the chunks over a Queue.
    WINDOWS_READS = Gem.win_platform?
    TRAP_SLICE = 0.1

    attr_reader :pid

    # ghost: windows nobody can see or touch (SCARPE_NATIVE_GHOST, native/DESIGN.md 12).
    def self.start(headless: false, ghost: false)
      args = []
      args << "--headless" if headless
      args << "--ghost" if ghost
      args.concat(Shellwords.split(ENV["SCARPE_NATIVE_ARGS"].to_s))
      new([Binary.path, *args])
    end

    def initialize(command, ready_timeout: READY_TIMEOUT)
      @log = Shoes::Log.logger("Scarpe::Native::Child")
      @trace = !ENV["SCARPE_NATIVE_TRACE"].to_s.empty?
      @ready_timeout = ready_timeout
      Stats.mark("spawn")
      @stdin, @stdout, @stderr, @wait_thread = spawn(command)
      @pid = @wait_thread.pid
      name_in_pid_file
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
      if WINDOWS_READS
        @chunks = Thread::Queue.new
        @stdout_thread = Thread.new { pump_stdout }
      else
        @wake_reader, @wake_writer = IO.pipe
      end

      say_hello
    end

    # Rust's version, from its answer to hello (waiting for it, the first time).
    def version
      ready["version"]
    end

    # A child that has not answered hello by now is stuck starting up: say so instead of waiting on.
    # The clock starts when Ruby first listens (the pump's first step), not at the spawn: the app
    # body runs between the two, with the answer unread in the pipe, and its time is not the child's.
    def check_started!
      return if @ready || @eof

      @listening_since ||= monotonic
      return if monotonic - @listening_since < @ready_timeout

      raise ChildTimeout, "scarpe-native did not answer hello within #{@ready_timeout}s"
    end

    def post(message)
      line = Stats.time(:encode) { encode(message) }
      @write_lock.synchronize { @outbox << line } if line
      # A download thread's change waits for the pump's flush: wake it rather than wait for a timer.
      wake! if line && !Thread.current.equal?(Thread.main)
    end

    # Ends a wait_for_input early. Safe from a signal trap, where Mutexes are off limits.
    def wake!
      return @chunks << :wake if WINDOWS_READS

      @wake_writer.write_nonblock(".", exception: false)
    rescue IOError
      nil
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
      close_stdin
      unless @wait_thread.join(grace)
        signal("TERM")
        signal("KILL") unless @wait_thread.join(1)
      end
      forget_pid_file
    end

    # Ends the child, and anything it started, at once: for when Ruby itself is being stopped and
    # has no time to wait for a child that may be stuck. Safe from a signal trap.
    def kill!
      signal("TERM") if @wait_thread.alive?
    end

    private

    # SCARPE_NATIVE_PID_FILE names the child's process group for as long as the child runs, so a
    # harness that had to kill Ruby (whose group signals never reach the child's) can end it too.
    def name_in_pid_file
      @pid_file = ENV["SCARPE_NATIVE_PID_FILE"].to_s
      File.write(@pid_file, "#{@pid}\n") unless @pid_file.empty?
    rescue SystemCallError => e
      @log.warn("Could not write SCARPE_NATIVE_PID_FILE #{@pid_file}: #{e.message}")
      @pid_file = ""
    end

    def forget_pid_file
      File.delete(@pid_file) unless @pid_file.empty? || !File.exist?(@pid_file)
    rescue SystemCallError
      nil
    end

    def close_stdin
      @write_lock.synchronize do
        write_outbox
        @stdin.close unless @stdin.closed?
      end
    rescue IOError, SystemCallError
      nil
    end

    # Its own process group, so a terminal Ctrl-C reaches Ruby (which quits the child) and not the child.
    # Windows has no pgroup; new_pgroup does the same there for a console's Ctrl-C.
    # The [path, argv0] form never goes through /bin/sh: a lone path would when it holds a parenthesis,
    # and a double-click passes no flags, so "ZARKING (Rust).app" died there. An env hash may lead.
    def spawn(command)
      env, (program, *args) = command.partition { |part| part.is_a?(Hash) }
      # Windows runs no shebang line, so a Ruby stand-in for the binary goes through this Ruby there.
      program, *args = RbConfig.ruby, program, *args if Gem.win_platform? && program.end_with?(".rb")
      Open3.popen3(*env, [program, program], *args, **OWN_GROUP)
    rescue SystemCallError => e
      raise ChildNotFound, "Can't start #{program}: #{e.message}"
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
      return read_queued(timeout) if WINDOWS_READS

      readable, = IO.select([@stdout, @wake_reader], nil, nil, timeout)
      return unless readable

      @wake_reader.read_nonblock(4096, exception: false) if readable.include?(@wake_reader)
      return unless readable.include?(@stdout)

      chunk = @stdout.read_nonblock(65_536, exception: false)
      return if chunk == :wait_readable
      return @eof = true if chunk.nil?

      take(chunk)
    rescue IOError, SystemCallError
      @eof = true
    end

    # read_some for Windows: what pump_stdout has read, or :wake, or :eof. A signal trap (Ctrl-C's
    # wake!) runs only once pop comes back, so a long wait goes in slices.
    def read_queued(timeout)
      deadline = monotonic + timeout
      chunk = @chunks.pop(timeout: timeout.clamp(0, TRAP_SLICE))
      chunk = @chunks.pop(timeout: (deadline - monotonic).clamp(0, TRAP_SLICE)) while chunk.nil? && monotonic < deadline
      while chunk
        case chunk
        when :eof then return @eof = true
        when String then take(chunk)
        end
        chunk = @chunks.empty? ? nil : @chunks.pop
      end
    end

    def pump_stdout
      loop { @chunks << @stdout.readpartial(65_536) }
    rescue EOFError, IOError, SystemCallError
      @chunks << :eof
    end

    def take(chunk)
      @read_buffer << chunk
      while (newline = @read_buffer.index("\n"))
        accept(@read_buffer.slice!(0..newline))
      end
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

    # One JSON::State per thread, kept: JSON.generate builds a new one per call, which halves its
    # speed on Ruby 3.2's json (native/PERF.md). A state counts nesting as it goes, hence per thread.
    def encode(message)
      (Thread.current[:scarpe_native_json] ||= JSON::State.new).generate(message)
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
        Scarpe::Native.diagnostics.write(line)
        @stderr_lock.synchronize do
          @stderr_tail << line
          @stderr_tail.shift while @stderr_tail.size > STDERR_TAIL_LINES
        end
      end
    rescue IOError, SystemCallError
      nil
    end

    # To the child's whole process group (it leads one), so what it started goes with it.
    # Windows has neither TERM nor groups to signal, so there the child is ended outright.
    def signal(name)
      Gem.win_platform? ? Process.kill("KILL", @pid) : Process.kill(name, -@pid)
    rescue SystemCallError
      nil
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
