# frozen_string_literal: true

require "json"
require "stringio"

module Scarpe::Native
  # The program's side of Shoes.run_program (DESIGN 5.5). exe/scarpe, and a packaged app's
  # boot.rb, hand a file here instead of to Shoes.run_app when SCARPE_RUN_FILE names it. With
  # SCARPE_REPORT_FD set too, the program reports to the process that started it (Programs):
  # what it writes to $stdout and $stderr, every error Shoes.on_error hears (its startup, its
  # handlers and timers, its end), and its renderer's pid. Scarpe's own lines go to the stderr
  # it was given. When the pipe named by SCARPE_PARENT_FD reaches its end, the parent is gone,
  # and the program stops, its window with it.
  module ProgramChild
    extend self

    # Settings the parent passes, read once and taken out of ENV so a program this one starts
    # gets its own.
    SETTINGS = %w[SCARPE_RUN_FILE SCARPE_RUN_DIR SCARPE_RUN_ARGS SCARPE_REPORT_FD SCARPE_PARENT_FD].freeze
    # After TERM on its parent's death, the time a program has to end before it ends itself.
    PARENT_GONE_GRACE = 1.0

    # Runs the Shoes program at path, in SCARPE_RUN_DIR (its own directory by default) with
    # SCARPE_RUN_ARGS (JSON) as its ARGV. A program that cannot start has said why on the pipe
    # (Shoes.run_app reports it as "startup"), and exits 1 without printing it again.
    def run(path)
      settings = take_settings
      reporting = install(settings)
      ARGV.replace(Array(settings[:args]))
      begin
        Shoes.run_app(path, dir: settings[:dir])
      rescue SystemExit, SignalException, NoMemoryError
        raise
      rescue Exception
        raise unless reporting

        exit 1
      end
    end

    # Whether this process reports to a parent.
    def reporting?
      !@report.nil?
    end

    # One report to the parent, a JSON line. From any thread, and from a signal trap (where a
    # Mutex is off limits, so the line goes out without it). A parent that is gone is ignored:
    # the parent pipe says so, and the program stops.
    def send_report(message)
      return unless @report

      line = "#{JSON.generate(plain(message))}\n"
      begin
        @lock.synchronize { @report.write(line) }
      rescue ThreadError
        @report.write(line)
      end
      nil
    rescue JSON::GeneratorError, IOError, SystemCallError
      nil
    end

    # Every String valid UTF-8, so the report is JSON whatever bytes an error or a line held.
    def plain(value)
      case value
      when String then value.encoding == Encoding::UTF_8 && value.valid_encoding? ? value : value.dup.force_encoding(Encoding::UTF_8).scrub("?")
      when Hash then value.to_h { |key, v| [key, plain(v)] }
      when Array then value.map { |v| plain(v) }
      else value
      end
    end

    private

    def take_settings
      raw = SETTINGS.to_h { |name| [name, ENV.delete(name)] }
      {
        dir: raw["SCARPE_RUN_DIR"],
        args: raw["SCARPE_RUN_ARGS"] ? JSON.parse(raw["SCARPE_RUN_ARGS"]) : [],
        report_fd: raw["SCARPE_REPORT_FD"]&.then { |fd| Integer(fd) },
        parent_fd: raw["SCARPE_PARENT_FD"]&.then { |fd| Integer(fd) },
      }
    rescue JSON::ParserError, ArgumentError
      { dir: raw["SCARPE_RUN_DIR"], args: [], report_fd: nil, parent_fd: nil }
    end

    def install(settings)
      watch_parent(settings[:parent_fd]) if settings[:parent_fd]
      return false unless settings[:report_fd]

      @report = open_fd(settings[:report_fd], "w")
      @report.sync = true
      @lock = Mutex.new
      Scarpe::Native.diagnostics = STDERR
      $stdout = Output.new("stdout")
      $stderr = Output.new("stderr")
      Shoes.on_error { |err| send_report(t: "error", error: err) }
      Child.prepend(ReportsRenderer)
      Pump.prepend(ReportsTheEnd)
      at_exit { [$stdout, $stderr].each { |io| io.finish if io.is_a?(Output) } }
      true
    rescue SystemCallError, ArgumentError => e
      @report = nil
      STDERR.puts("[scarpe-native] Scarpe::Native::ProgramChild warn: cannot report to the parent: #{e.message}")
      false
    end

    # Inherited descriptors, kept from anything this program starts (its renderer included),
    # so the parent sees the report pipe end when this process does.
    def open_fd(fd, mode)
      io = IO.for_fd(fd, mode, autoclose: true)
      io.close_on_exec = true
      io
    end

    # The parent holds the other end and never writes: its end means the parent has gone.
    # TERM ends the program as Ctrl-C's second press would, its renderer first (DisplayService
    # kill_on_term); one that ignores TERM is ended a second later.
    def watch_parent(fd)
      io = open_fd(fd, "r")
      Thread.new do
        begin
          io.read
        rescue IOError, SystemCallError
          nil
        end
        Process.kill("TERM", Process.pid)
        sleep PARENT_GONE_GRACE
        DisplayService.instance&.started_child&.kill!
        Process.exit!(1)
      end
    rescue SystemCallError, ArgumentError
      nil
    end

    # $stdout and $stderr for a program that reports: each whole line goes to the parent as
    # {"t":"output"}. StringIO's puts, print, printf, << and p all end in write.
    class Output < StringIO
      def initialize(stream)
        super(+"")
        @stream = stream
        @pending = String.new(encoding: Encoding::UTF_8)
        @lock = Mutex.new
      end

      def write(*strings)
        exclusively do
          strings.sum do |string|
            string = string.to_s
            @pending << text(string)
            while (newline = @pending.index("\n"))
              ProgramChild.send_report(t: "output", stream: @stream, line: @pending.slice!(0..newline).chomp)
            end
            string.bytesize
          end
        end
      end

      def putc(char)
        write(char.is_a?(Integer) ? (char & 0xff).chr : char.to_s[0].to_s)
        char
      end

      def flush
        self
      end

      def fsync
        0
      end

      # What is left without a newline, as the program ends.
      def finish
        ProgramChild.send_report(t: "output", stream: @stream, line: @pending.slice!(0..)) unless @pending.empty?
      end

      private

      # One writer's lines at a time. A signal trap may not take the lock, and a report that
      # Ruby prints while writing one is already this thread's: those go straight through.
      def exclusively
        locked = begin
          @lock.lock
          true
        rescue ThreadError
          false
        end
        yield
      ensure
        @lock.unlock if locked
      end

      def text(string)
        string = string.dup.force_encoding(Encoding::UTF_8) unless string.encoding == Encoding::UTF_8
        string.valid_encoding? ? string : string.scrub("?")
      end
    end

    # The parent ends the renderer if the program cannot: it needs its pid, and to hear when it
    # has gone, so a later stop never signals a process that is someone else's by then.
    module ReportsRenderer
      def initialize(...)
        super(...)
        ProgramChild.send_report(t: "renderer", pid: pid)
      end

      def close(...)
        super(...)
      ensure
        ProgramChild.send_report(t: "renderer", pid: nil)
      end
    end

    # An error that escapes the event loop ends the program ("exit"): the renderer died under
    # it, say (ChildDied). The parent has heard it, so it ends with status 1 and is not printed.
    module ReportsTheEnd
      def run
        super
      rescue SystemExit, SignalException, NoMemoryError
        raise
      rescue Exception => e
        Shoes.report_error(e, during: "exit")
        exit 1
      end
    end
  end
end
