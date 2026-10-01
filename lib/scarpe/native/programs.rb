# frozen_string_literal: true

require "json"
require "rbconfig"
require "securerandom"
require "socket"

module Scarpe::Native
  # The Shoes programs Shoes.run_program started (DESIGN 5.5), each in a process of its own on
  # the Ruby and Scarpe this one runs: exe/scarpe --native from a checkout, or the packaged
  # app's own launcher. So an endless loop in a program freezes only it, and stop ends it.
  #
  # The child reports on a pipe it inherits as fd 3 (SCARPE_REPORT_FD), one JSON object a line:
  #
  #   {"t":"renderer","pid":N}                            its Rust renderer, so stop can end it
  #   {"t":"output","stream":"stdout","line":"..."}       a line it wrote to $stdout or $stderr
  #   {"t":"error","error":{Shoes::ErrorReport's Hash}}   a handler, timer, startup or exit raised
  #
  # and holds the read end of another as fd 4 (SCARPE_PARENT_FD): when this process ends, the
  # child reads the end of it and stops, so no window outlives the program that opened it.
  #
  # Windows can hand a child neither fd 3 and 4 nor a TERM, so there the two pipes are one
  # loopback connection instead (SOCKET_REPORTS): the child connects to SCARPE_REPORT_ADDR,
  # proves itself with SCARPE_REPORT_TOKEN, and reports up it the same JSON lines. Its end tells
  # the child its parent has gone, and a "stop" line down it stands in for TERM: the child sends
  # TERM to itself, which Windows does deliver.
  # Threads here only read pipes and wait for processes; what they hear waits in the inbox
  # until the pump hands it to the program's blocks (Shoes::Program), on the event loop.
  class Programs
    REPORT_FD = 3
    PARENT_FD = 4
    SOCKET_REPORTS = Gem.win_platform?
    # How long a program has to go after TERM before it gets KILL.
    GRACE = 1.0
    # News handed out per turn of the loop, so a program that floods its output never stalls this one.
    PER_TURN = 500
    # Lines of output held for the event loop at most; past that, lines are left out and counted.
    MAX_WAITING = 10_000
    # A spec run's settings are the parent's own: its test code, its results, its renderer's pid.
    PARENT_ONLY_ENV = %w[
      SHOES_SPEC_TEST SHOES_MINITEST_EXPORT_FILE SHOES_MINITEST_CLASS_NAME SHOES_MINITEST_METHOD_NAME
      SCARPE_NATIVE_PID_FILE SCARPE_NATIVE_STATS SCARPE_TEST_CONTROL SCARPE_TEST_RESULTS SCARPE_RUN_FILE
    ].freeze

    def initialize(service)
      @service = service
      @inbox = Thread::Queue.new
      @running = {}
      @lock = Mutex.new
    end

    # @return [Shoes::Program]
    def start(path, dir:, args:)
      process = ProgramProcess.new(self, path)
      program = Shoes::Program.new(path, dir: dir, args: args, driver: process)
      process.program = program
      process.spawn(command_for(path), env_for(path, dir, args), dir)
      program
    end

    # Whether news is waiting for the pump.
    def waiting?
      !@inbox.empty?
    end

    # On the pump: hands the waiting news to each program's blocks, a bounded amount a turn.
    def dispatch
      PER_TURN.times do
        process, kind, payload = begin
          @inbox.pop(true)
        rescue ThreadError
          break
        end
        @service.guarded("#{File.basename(process.path)} program's #{kind} block") { deliver(process, kind, payload) }
      end
    end

    # Every program still running, stopped: TERM, then KILL once `wait` is up. At exit.
    def stop_all(wait: GRACE)
      processes = @lock.synchronize { @running.values }
      return if processes.empty?

      processes.each { |process| process.signal("TERM") }
      deadline = monotonic + wait
      sleep 0.02 while processes.any?(&:alive?) && monotonic < deadline
      processes.each(&:kill!)
    end

    # From the threads below: news for the pump.
    def post(process, kind, payload = nil)
      if kind == :output && @inbox.size >= MAX_WAITING
        process.left_out += 1
        return
      end
      @inbox << [process, kind, payload]
      @service.wake!
    end

    # A process is kept from its spawn, before its threads can forget it, until it has gone.
    def track(process)
      @lock.synchronize { @running[process.pid] = process }
    end

    def forget(process)
      @lock.synchronize { @running.delete(process.pid) }
    end

    private

    def deliver(process, kind, payload)
      program = process.program
      case kind
      when :output
        program.deliver_output(payload["stream"].to_s, payload["line"].to_s)
      when :error
        program.deliver_error(payload)
      when :exit
        if process.left_out.positive?
          program.deliver_output("stderr", "(#{process.left_out} more lines the program wrote were left out)")
        end
        program.deliver_exit(payload)
      end
    end

    # A packaged app starts its own launcher again, which runs SCARPE_RUN_FILE instead of the
    # app; a checkout runs exe/scarpe --native on this Ruby, with this Scarpe on its load path.
    def command_for(path)
      launcher = ENV["SCARPE_LAUNCHER"].to_s
      return [launcher] if !launcher.empty? && File.executable?(launcher)

      libs = %w[lib lacci/lib scarpe-components/lib].map { |dir| File.join(ROOT, dir) }.select { |dir| File.directory?(dir) }
      [RbConfig.ruby, *libs.flat_map { |dir| ["-I", dir] }, File.join(ROOT, "exe", "scarpe"), "--native", path]
    end

    # The child inherits this environment, headless and ghost modes included, less the parent's
    # own. ProgramProcess#spawn adds where it reports to.
    def env_for(path, dir, args)
      PARENT_ONLY_ENV.to_h { |name| [name, nil] }.merge(
        "SCARPE_DISPLAY_SERVICE" => "native",
        "SCARPE_RUN_FILE" => path,
        "SCARPE_RUN_DIR" => dir,
        "SCARPE_RUN_ARGS" => JSON.generate(args),
      )
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  # One program's process, and its side of Shoes::Program: pid and stop.
  class ProgramProcess
    # The program's renderer, from the moment it says it started one until it says it is gone.
    attr_reader :path, :pid, :renderer_pid
    attr_accessor :program, :left_out

    def initialize(programs, path)
      @programs = programs
      @path = path
      @left_out = 0
      @renderer_pid = nil
      @reaped = false
    end

    # Its own process group, so stop reaches whatever the program started too; stdin is
    # /dev/null, and stdout and stderr are this process's, for what Scarpe itself says there.
    # The command's first word goes as [name, argv0], so Ruby never reads a lone launcher as a
    # command line and splits it at the space in "Hackety Hack.app".
    def spawn(command, env, dir)
      return spawn_reporting_by_socket(command, env, dir) if Programs::SOCKET_REPORTS

      env = env.merge("SCARPE_REPORT_FD" => Programs::REPORT_FD.to_s, "SCARPE_PARENT_FD" => Programs::PARENT_FD.to_s)
      report_read, report_write = IO.pipe
      parent_read, @parent_write = IO.pipe
      name, *args = command
      @pid = Process.spawn(env, [name, name], *args, Programs::REPORT_FD => report_write, Programs::PARENT_FD => parent_read,
        in: File::NULL, pgroup: true, chdir: dir)
      [report_write, parent_read].each(&:close)
      @programs.track(self)
      @reader = Thread.new { read_reports(report_read) }
      @waiter = Thread.new { wait_for_exit }
    rescue SystemCallError => e
      [report_read, report_write, parent_read, @parent_write].compact.each { |io| io.close unless io.closed? }
      raise Scarpe::Native::ChildNotFound, "Could not start #{File.basename(path)}: #{e.message}"
    end

    # Windows (Programs::SOCKET_REPORTS): the child gets an address and a token instead of fds,
    # and its own process group for Ctrl-C's sake. The reader accepts its connection, and only
    # one that starts with the token.
    def spawn_reporting_by_socket(command, env, dir)
      @server = TCPServer.new("127.0.0.1", 0)
      token = SecureRandom.hex(16)
      env = env.merge("SCARPE_REPORT_ADDR" => "127.0.0.1:#{@server.addr[1]}", "SCARPE_REPORT_TOKEN" => token)
      name, *args = command
      @pid = Process.spawn(env, [name, name], *args, in: File::NULL, new_pgroup: true, chdir: dir)
      @programs.track(self)
      @reader = Thread.new { read_reports_from_socket(token) }
      @waiter = Thread.new { wait_for_exit }
    rescue SystemCallError => e
      @server&.close
      raise Scarpe::Native::ChildNotFound, "Could not start #{File.basename(path)}: #{e.message}"
    end

    def alive?
      !@reaped
    end

    # TERM now, and KILL a second later if it is still there. The program's renderer goes with
    # it: the program ends its renderer when it gets TERM, a renderer whose program is gone
    # stops at the end of its stdin, and a KILL reaches the renderer too.
    def stop
      return unless alive?

      signal("TERM")
      Thread.new do
        sleep Programs::GRACE
        kill!
      end
      nil
    end

    def kill!
      signal("KILL") if alive?
      end_renderer
    end

    def signal(name)
      return signal_on_windows(name) if Programs::SOCKET_REPORTS

      Process.kill(name, -@pid)
    rescue SystemCallError
      nil
    end

    # No TERM for another process on Windows: ask over the connection, where the child TERMs
    # itself. KILL ends it outright.
    def signal_on_windows(name)
      if name == "TERM"
        @socket&.write("stop\n")
      else
        Process.kill(name, @pid)
      end
    rescue IOError, SystemCallError
      nil
    end

    private

    def read_reports(io)
      io.each_line do |line|
        message = JSON.parse(line)
        case message["t"]
        when "renderer" then @renderer_pid = message["pid"] && Integer(message["pid"])
        when "output" then @programs.post(self, :output, message)
        when "error" then @programs.post(self, :error, message["error"])
        end
      rescue JSON::ParserError, ArgumentError, TypeError
        next
      end
    rescue IOError, SystemCallError
      nil
    ensure
      io.close unless io.closed?
    end

    # A blocking accept: IO.select never saw the listening socket ready on Windows. If the
    # program ends without connecting, wait_for_exit closes the server and accept gives up.
    def read_reports_from_socket(token)
      until @socket
        candidate = @server.accept
        if candidate.gets("\n", 100).to_s.chomp == token
          @socket = candidate
        else
          candidate.close
        end
      end
      @server.close
      read_reports(@socket)
    rescue IOError, SystemCallError
      nil
    ensure
      @server.close unless @server.closed?
    end

    # The exit waits for the last reports, so a program's final error comes before its exit.
    def wait_for_exit
      status = begin
        Process.wait2(@pid).last
      rescue SystemCallError
        nil # reaped by someone else's wait
      end
      # A program that connected, reported and ended at once may still wait in the server's
      # queue: let the reader take it before closing the server under it.
      @reader.join(2)
      @server&.close unless @server&.closed?
      @reader.join(1)
      @reaped = true
      @parent_write.close if @parent_write && !@parent_write.closed?
      @socket.close if @socket && !@socket.closed?
      end_renderer
      @programs.forget(self)
      @programs.post(self, :exit, status)
    end

    # A renderer outlives its program only for the moment it takes to read the end of its
    # stdin; one still there then is stuck, and gets KILL.
    def end_renderer
      pid = @renderer_pid or return
      @renderer_pid = nil
      Process.kill("KILL", Programs::SOCKET_REPORTS ? pid : -pid)
    rescue SystemCallError
      nil
    end
  end
end
