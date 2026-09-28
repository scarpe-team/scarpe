# frozen_string_literal: true

require "json"
require "rbconfig"

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
  # Threads here only read pipes and wait for processes; what they hear waits in the inbox
  # until the pump hands it to the program's blocks (Shoes::Program), on the event loop.
  class Programs
    REPORT_FD = 3
    PARENT_FD = 4
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

    # The child inherits this environment, headless and ghost modes included, less the parent's own.
    def env_for(path, dir, args)
      PARENT_ONLY_ENV.to_h { |name| [name, nil] }.merge(
        "SCARPE_DISPLAY_SERVICE" => "native",
        "SCARPE_RUN_FILE" => path,
        "SCARPE_RUN_DIR" => dir,
        "SCARPE_RUN_ARGS" => JSON.generate(args),
        "SCARPE_REPORT_FD" => REPORT_FD.to_s,
        "SCARPE_PARENT_FD" => PARENT_FD.to_s,
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
      Process.kill(name, -@pid)
    rescue SystemCallError
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

    # The exit waits for the last reports, so a program's final error comes before its exit.
    def wait_for_exit
      status = begin
        Process.wait2(@pid).last
      rescue SystemCallError
        nil # reaped by someone else's wait
      end
      @reader.join(2)
      @reaped = true
      @parent_write.close unless @parent_write.closed?
      end_renderer
      @programs.forget(self)
      @programs.post(self, :exit, status)
    end

    # A renderer outlives its program only for the moment it takes to read the end of its
    # stdin; one still there then is stuck, and gets KILL.
    def end_renderer
      pid = @renderer_pid or return
      @renderer_pid = nil
      Process.kill("KILL", -pid)
    rescue SystemCallError
      nil
    end
  end
end
