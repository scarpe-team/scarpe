# frozen_string_literal: true

class Shoes
  # A Shoes program started by Shoes.run_program: a handle on it, and the place its news
  # arrives. The display service runs it (the native one in a process of its own) and hands
  # what the program reports to deliver_error, deliver_output and deliver_exit on the event
  # loop, so every block given here runs there, never on a thread.
  #
  #   program = Shoes.run_program("/path/to/game.rb")
  #   program.on_output { |stream, line| @out.text += line + "\n" }
  #   program.on_error { |err| show_the_error(err) }   # err: Shoes::ErrorReport's Hash
  #   program.on_exit { |status| @run.show }
  #   program.stop
  #
  # A block added after the news it waits for still hears it: on_error is handed the errors
  # reported so far, and on_exit the status, once the program has ended.
  class Program
    # Errors kept for an on_error block added later.
    KEPT_ERRORS = 100

    attr_reader :path, :dir, :args

    # The display service's side of one program: its pid, and stop, which does nothing once
    # there is nothing left to stop.
    # @param driver [#pid, #stop]
    def initialize(path, dir:, args:, driver:)
      @path = path
      @dir = dir
      @args = args
      @driver = driver
      @errors = []
      @status = nil
      @exited = false
      @on_exit = []
      @on_error = []
      @on_output = []
    end

    # The program's process id, or nil when it runs inside this process.
    def pid
      @driver.pid
    end

    # True until the program has ended and on_exit has been told.
    def running?
      !@exited
    end

    # How it ended: a Process::Status for a program in a process of its own, nil for one that
    # ran inside this one, or nil while it is still running.
    attr_reader :status

    # Stops the program: TERM, then KILL a second later if it is still there, and its window
    # goes with it. on_exit hears about it as usual. A program that has ended ignores it, but
    # for one that ran inside this process, stop closes the windows it left open.
    #
    # @return [Shoes::Program] self
    def stop
      @driver.stop
      self
    end

    # @yieldparam status [Process::Status, nil]
    def on_exit(&block)
      @on_exit << block
      block.call(@status) if @exited
      self
    end

    # @yieldparam err [Hash{String => Object}] class, message, backtrace, path, line, during
    def on_error(&block)
      @on_error << block
      @errors.each { |err| block.call(err) }
      self
    end

    # @yieldparam stream [String] "stdout" or "stderr"
    # @yieldparam line [String] one line, without its newline
    def on_output(&block)
      @on_output << block
      self
    end

    # For display services, on the event loop: the program reported an error.
    def deliver_error(err)
      @errors << err
      @errors.shift while @errors.size > KEPT_ERRORS
      @on_error.each { |block| block.call(err) }
    end

    # For display services, on the event loop: the program wrote a line.
    def deliver_output(stream, line)
      @on_output.each { |block| block.call(stream, line) }
    end

    # For display services, on the event loop: the program ended. Only the first counts.
    def deliver_exit(status)
      return if @exited

      @exited = true
      @status = status
      @on_exit.each { |block| block.call(status) }
    end

    def inspect
      "#<Shoes::Program #{File.basename(@path.to_s)} pid=#{pid.inspect} #{@exited ? "ended" : "running"}>"
    end

    # Runs the program inside this process, as Shoes 3 ran programs and Hackety Hack's Run did
    # before Scarpe could start processes: for displays that cannot start one (Niente, the
    # webview). Its windows open in this process and stay when it is done; an error while it
    # loads reaches on_error, and then on_exit hears nil. Its output is this process's, and
    # errors in its handlers go to Shoes.on_error. stop closes the windows it opened.
    class InProcess
      def initialize
        @apps = []
      end

      attr_accessor :apps

      def pid
        nil
      end

      # Closes each window the program opened, as its own close would (App#close, ledger A8).
      def stop
        @apps.each { |app| app.close if Shoes.APPS.include?(app) }
      end

      def self.run(path, dir:, args:)
        Shoes::Log.logger("Shoes::Program").warn(
          "This display cannot start a process, so #{File.basename(path)} runs inside this program " \
          "(an endless loop in it will stop this one too)."
        )
        driver = new
        program = Shoes::Program.new(path, dir: dir, args: args, driver: driver)
        before = Shoes.APPS.dup
        begin
          load path
        rescue SystemExit
          nil
        rescue StandardError, ScriptError, SystemStackError => e
          program.deliver_error(Shoes.report_error(e, during: "startup", program: path))
        end
        driver.apps = Shoes.APPS - before
        program.deliver_exit(nil)
        program
      end
    end
  end
end
