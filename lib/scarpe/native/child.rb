# frozen_string_literal: true

require "fileutils"
require "monitor"
require "open3"
require "shellwords"

module Scarpe::Native
  class ChildDied < Scarpe::Error; end
  class ChildNotFound < Scarpe::Error; end
  class ChildTimeout < Scarpe::Error; end

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

    attr_reader :pid, :version

    def self.start(headless: false)
      args = []
      args << "--headless" if headless
      args.concat(Shellwords.split(ENV["SCARPE_NATIVE_ARGS"].to_s))
      new([Binary.path, *args])
    end

    def initialize(command)
      @log = Shoes::Log.logger("Scarpe::Native::Child")
      @trace = !ENV["SCARPE_NATIVE_TRACE"].to_s.empty?
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

      handshake
    end

    def post(message)
      line = encode(message)
      @write_lock.synchronize { @outbox << line } if line
    end

    # Ends a batch: Rust applies everything, lays out and paints once.
    def flush
      @write_lock.synchronize do
        next if @outbox.empty?

        @outbox << encode(t: "flush")
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

    def handshake
      post(t: "hello", v: PROTOCOL_VERSION, pid: Process.pid)
      @write_lock.synchronize { write_outbox }
      ready = await("the ready handshake", timeout: READY_TIMEOUT) do
        index = @inbox.index { |message| message["t"] == "ready" }
        index && @inbox.delete_at(index)
      end
      @version = ready["version"]
      @log.warn("scarpe-native speaks protocol #{ready["v"].inspect}, we speak #{PROTOCOL_VERSION}") if ready["v"] != PROTOCOL_VERSION
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
      message = JSON.parse(line)
      if message["t"] == "reply"
        @replies[message["req"]] = message
      else
        @inbox << message
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
      @stdin.write(lines.join("\n") << "\n")
      @stdin.flush
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
