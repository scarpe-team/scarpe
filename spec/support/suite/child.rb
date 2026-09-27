# frozen_string_literal: true

module SpecSuite
  # Runs one command in its own process group with a deadline, output to a log file.
  # Past the deadline the whole group gets TERM, then KILL, so a display child or a stray
  # grandchild never outlives its case.
  class Child
    Finished = Struct.new(:exitstatus, :termsig, :timed_out, :secs, :log, keyword_init: true) do
      def output
        File.exist?(log) ? File.read(log, encoding: "UTF-8", invalid: :replace, undef: :replace) : ""
      end
    end

    GRACE = 1.0
    POLL = 0.02

    def self.run(argv, env:, chdir:, log:, deadline_after:)
      new(argv, env:, chdir:, log:).run(deadline_after)
    end

    def initialize(argv, env:, chdir:, log:)
      @argv = argv
      @env = env
      @chdir = chdir
      @log = log
    end

    def run(deadline_after)
      started = now
      pid = Process.spawn(@env, *@argv, chdir: @chdir, in: File::NULL, out: @log, err: [:child, :out],
        pgroup: true, unsetenv_others: true)
      status = wait_until(pid, started + deadline_after)
      timed_out = status.nil?
      status ||= stop(pid)
      Finished.new(exitstatus: status.exitstatus, termsig: status.termsig, timed_out:, secs: (now - started).round(2),
        log: @log)
    ensure
      kill_group(pid, "KILL") if pid
    end

    private

    def wait_until(pid, deadline)
      loop do
        _, status = Process.wait2(pid, Process::WNOHANG)
        return status if status
        return nil if now > deadline

        sleep POLL
      end
    end

    def stop(pid)
      kill_group(pid, "TERM")
      wait_until(pid, now + GRACE) || begin
        kill_group(pid, "KILL")
        Process.wait2(pid).last
      end
    end

    def kill_group(pid, signal)
      Process.kill(signal, -pid)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
