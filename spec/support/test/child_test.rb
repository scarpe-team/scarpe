# frozen_string_literal: true

require_relative "helper"

class ChildTest < Minitest::Test
  # The native renderer leads a process group of its own, which a timed-out case's signals to
  # Ruby's group never reach, and a renderer stuck in layout never reads the EOF that says Ruby
  # died (review). The shim names it in SCARPE_NATIVE_PID_FILE for as long as it runs.
  def test_a_timed_out_case_takes_the_renderers_group_down_too
    Dir.mktmpdir do |dir|
      pid_file = File.join(dir, "renderer.pid")
      app = <<~RUBY
        renderer = Process.spawn(#{RbConfig.ruby.inspect}, "-e", "sleep 30", **#{SpecSuite::Child::OWN_GROUP.inspect})
        File.write(ENV["SCARPE_NATIVE_PID_FILE"], renderer.to_s)
        sleep 30
      RUBY
      finished = SpecSuite::Child.run([RbConfig.ruby, "-e", app], env: { "SCARPE_NATIVE_PID_FILE" => pid_file },
        chdir: dir, log: File.join(dir, "out.log"), deadline_after: 1)
      renderer = Integer(File.read(pid_file))

      assert finished.timed_out
      assert gone_soon?(renderer), "the renderer outlived its case"
    ensure
      Process.kill("KILL", renderer) if renderer && !gone_soon?(renderer, 0)
    end
  end

  private

  def gone_soon?(pid, seconds = 2)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    loop do
      Process.kill(0, pid)
      return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.02
    end
  rescue Errno::ESRCH
    true
  end
end
