# frozen_string_literal: true

require_relative "helper"
require "fileutils"
require "shellwords"

# Shoes.run_program (DESIGN 5.5): a Shoes program in a process of its own, on the same Ruby and
# Scarpe, reporting its output and errors to the app that started it, headless like its parent.
# The parent's test code follows it with wait_until, since what a program says comes in real
# time while the spec clock stands still.
class ProgramTest < Minitest::Test
  include NativeTestHelpers

  def setup
    skip_on_windows("Shoes.run_program runs in this process there")
    skip_without_real_binary
  end

  # Runs test_code in a parent app, with program written beside it as program.rb.
  def run_parent(program, test_code, timeout: 60, env: {}, &setup)
    run_real(<<~APP, test_code: test_code, timeout: timeout, env: env) do |dir|
      Shoes.app { para "the parent" }
    APP
      File.write(File.join(dir, "program.rb"), program)
      setup&.call(dir)
    end
  end

  # Neither running nor a zombie: `ps` knows nothing of it, or knows it only as defunct.
  GONE = <<~RUBY
    gone = ->(pid) { pid.nil? || `ps -o stat= -p \#{Integer(pid)}`.strip.then { |s| s.empty? || s.start_with?("Z") } }
  RUBY

  def test_output_lines_arrive_in_order
    run = run_parent(<<~PROGRAM, <<~TEST)
      puts "hello from the program"
      p [1, 2]
      $stdout.print "no newline yet"
      $stdout.print ", now one\\n"
      warn "careful"
      puts "caf\\xE9".b
      Shoes.app { para "the program" }
    PROGRAM
      program = Shoes.run_program(File.join(Dir.pwd, "program.rb"))
      lines = []
      program.on_output { |stream, line| lines << [stream, line] }
      wait_until(30) { lines.size >= 5 }
      assert_equal [["stdout", "hello from the program"], ["stdout", "[1, 2]"], ["stdout", "no newline yet, now one"],
        ["stderr", "careful"], ["stdout", "caf?"]], lines, "in order, bytes that are not UTF-8 marked, not lost"
      assert program.running?, "it keeps running with its window open"
      assert_kind_of Integer, program.pid
      program.stop
      wait_until(5) { !program.running? }
    TEST
    assert_spec_passed(run)
  end

  # The classic freeze: a program that never stops. It freezes only itself, and stop ends it
  # and its renderer within two seconds, with nothing left behind.
  def test_stop_ends_a_program_that_loops_forever_and_leaves_nothing
    run = run_parent(<<~PROGRAM, GONE + <<~TEST)
      Shoes.app do
        para "stuck"
        timer(0.1) do
          puts "looping"
          system("sleep 60 &") # something the program started, in its process group
          loop {}
        end
      end
    PROGRAM
      program = Shoes.run_program(File.join(Dir.pwd, "program.rb"))
      said = []
      program.on_output { |_stream, line| said << line }
      exited = nil
      program.on_exit { |status| exited = status }
      wait_until(30) { said.include?("looping") }
      process = program.instance_variable_get(:@driver)
      wait_until(5) { process.renderer_pid }
      renderer = process.renderer_pid
      group = `pgrep -g \#{program.pid}`.split.map(&:to_i)

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      program.stop
      wait_until(5) { !program.running? }
      took = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      assert_operator took, :<, 2.0, "stopped within two seconds"
      assert exited.signaled?, "it was stopped by a signal: \#{exited.inspect}"
      assert gone.call(program.pid), "the program is gone"
      wait_until(2) { gone.call(renderer) }
      assert gone.call(renderer), "and its renderer"
      assert_empty `pgrep -g \#{program.pid}`.split, "and what it started (was \#{group.inspect})"
    TEST
    assert_spec_passed(run)
  end

  def test_an_error_in_a_button_reports_during_handler_with_its_line
    run = run_parent(<<~PROGRAM, <<~TEST)
      Shoes.app do
        @boom = button("Boom") do
          raise ArgumentError, "the button broke"
        end
        # a click through the renderer, the way a person's would arrive
        timer(0.2) { Scarpe::Native::DisplayService.instance.child.request(:click, target: { id: @boom.linkable_id }) }
        timer(0.5) { raise "the timer broke" }
      end
    PROGRAM
      path = File.join(Dir.pwd, "program.rb")
      program = Shoes.run_program(path)
      errors = []
      program.on_error { |err| errors << err }
      wait_until(30) { errors.size >= 2 }
      button, tick = errors
      assert_equal ["ArgumentError", "the button broke", "handler", 3], button.values_at("class", "message", "during", "line")
      assert_equal File.realpath(path), File.realpath(button["path"])
      assert_match(/program\\.rb:3:in/, button["backtrace"].first)
      assert_equal ["RuntimeError", "timer", 7], tick.values_at("class", "during", "line")
      assert program.running?, "an error in a handler does not end the program"
      assert_equal %w[class message backtrace path line during].sort, button.keys.sort
      late = []
      program.on_error { |err| late << err["class"] }
      assert_equal %w[ArgumentError RuntimeError], late, "a block added later hears the errors so far"
      program.stop
      wait_until(5) { !program.running? }
    TEST
    assert_spec_passed(run)
  end

  def test_a_syntax_error_reports_during_startup_and_ends_the_program
    run = run_parent(<<~PROGRAM, <<~TEST)
      Shoes.app do
        para "a program that forgot an end"
    PROGRAM
      program = Shoes.run_program(File.join(Dir.pwd, "program.rb"))
      errors = []
      said = []
      status = nil
      program.on_error { |err| errors << err }
      program.on_output { |_stream, line| said << line }
      program.on_exit { |s| status = s }
      wait_until(30) { status }
      assert_equal 1, errors.size
      assert_equal %w[SyntaxError startup], errors.first.values_at("class", "during")
      assert_kind_of Integer, errors.first["line"]
      assert_equal "program.rb", File.basename(errors.first["path"])
      assert_equal 1, status.exitstatus, "a program that cannot start ends with 1"
      assert_empty said, "and the error comes once, as an error, not again as output"
      refute program.running?
      finished = nil
      program.on_exit { |s| finished = s }
      assert_same status, finished, "a block added after the end hears it at once"
    TEST
    assert_spec_passed(run)
  end

  # The program's ARGV and working directory are the parent's to choose.
  def test_args_and_dir_reach_the_program
    run = run_parent(<<~PROGRAM, <<~TEST) { |dir| Dir.mkdir(File.join(dir, "elsewhere")) }
      puts ARGV.inspect
      puts File.basename(Dir.pwd)
      puts ENV.key?("SCARPE_RUN_FILE") || ENV.key?("SCARPE_REPORT_FD") || ENV.key?("SHOES_SPEC_TEST")
    PROGRAM
      program = Shoes.run_program(File.join(Dir.pwd, "program.rb"), dir: File.join(Dir.pwd, "elsewhere"), args: ["one", 2])
      lines = []
      program.on_output { |_stream, line| lines << line }
      wait_until(30) { !program.running? }
      assert_equal ['["one", "2"]', "elsewhere", "false"], lines, "its own settings are not handed on"
      assert_equal 0, program.status.exitstatus, "a program with no window just ends"
    TEST
    assert_spec_passed(run)
  end

  # A packaged app starts its own launcher again for a program, and a Mac app's name often has
  # a space in it ("Hackety Hack.app"). The launcher's path is one word, spaces and all.
  def test_a_launcher_whose_path_has_a_space_starts_the_program
    run = run_parent(<<~PROGRAM, <<~TEST) { |dir| write_launcher(File.join(dir, "Hackety Hack.app", "Contents", "MacOS")) }
      puts "started by \#{File.basename(ENV.fetch("LAUNCHED_BY", "nobody"))}"
    PROGRAM
      ENV["SCARPE_LAUNCHER"] = File.join(Dir.pwd, "Hackety Hack.app", "Contents", "MacOS", "scarpe-launcher")
      program = Shoes.run_program(File.join(Dir.pwd, "program.rb"))
      lines = []
      program.on_output { |_stream, line| lines << line }
      wait_until(30) { !program.running? }
      assert_equal ["started by scarpe-launcher"], lines
      assert_equal 0, program.status.exitstatus
    TEST
    assert_spec_passed(run)
  end

  # No window outlives the program that opened it: the program reads the end of the pipe its
  # parent holds, and stops, and its renderer with it. Here the parent dies of KILL.
  def test_killing_the_parent_ends_the_program_and_its_renderer
    Dir.mktmpdir("scarpe-native-program") do |dir|
      File.write(File.join(dir, "program.rb"), "Shoes.app { para 'orphan?' }\n")
      File.write(File.join(dir, "parent.rb"), <<~PARENT)
        Shoes.app do
          para "the parent"
          program = Shoes.run_program(File.join(__dir__, "program.rb"))
          every(0.1) do
            renderer = program.instance_variable_get(:@driver).renderer_pid
            File.write(File.join(__dir__, "pids.json"), JSON.generate([program.pid, renderer])) if renderer
          end
        end
      PARENT
      env = {
        "SCARPE_NATIVE_BIN" => NativeTestHelpers.real_binary, "SCARPE_NATIVE_ARGS" => "--fonts bundled",
        "SCARPE_NATIVE_HEADLESS" => "1", "SCARPE_NATIVE_GHOST" => nil,
        "SCARPE_NATIVE_PID_FILE" => File.join(dir, "renderer.pid"), "SCARPE_NATIVE_LOG_LEVEL" => "error",
      }
      parent = Process.spawn(env, RbConfig.ruby, SCARPE, "--dev", "--native", File.join(dir, "parent.rb"),
        out: File::NULL, err: File::NULL, in: File::NULL, pgroup: true, chdir: dir)
      pids = File.join(dir, "pids.json")
      begin
        assert until_true(45) { File.exist?(pids) && File.size?(pids) }, "the parent never started its program"
        program, renderer = JSON.parse(File.read(pids))
        assert alive?(program) && alive?(renderer)

        Process.kill("KILL", parent)
        Process.wait(parent)

        assert until_true(5) { !alive?(program) && !alive?(renderer) },
          "the program (#{program}) and its renderer (#{renderer}) outlived their parent"
      ensure
        [parent, program, renderer].compact.each { |pid| Process.kill("KILL", -pid) rescue nil }
        Process.wait(parent) rescue nil
        kill_renderer(env["SCARPE_NATIVE_PID_FILE"])
      end
    end
  end

  # The program says when its renderer starts and when it has gone, so stop never signals a
  # process group that could be someone else's by then.
  def test_the_renderer_it_reports_gone_is_forgotten
    programs = Scarpe::Native::Programs.new(Object.new)
    process = Scarpe::Native::ProgramProcess.new(programs, "/tmp/program.rb")
    read, write = IO.pipe
    write.puts JSON.generate(t: "renderer", pid: 4242)
    write.puts "not JSON"
    reader = Thread.new { process.send(:read_reports, read) }
    sleep 0.01 until process.renderer_pid
    assert_equal 4242, process.renderer_pid
    write.puts JSON.generate(t: "renderer", pid: nil)
    write.close
    reader.join(5)
    assert_nil process.renderer_pid, "a renderer the program closed is not KILLed later"
  end

  private

  # A stand-in for a packaged app's launcher (templates/package/native_launcher.sh.erb): it runs
  # SCARPE_RUN_FILE on this Ruby and Scarpe, as the real one does on the bundled ones.
  def write_launcher(dir)
    FileUtils.mkdir_p(dir)
    path = File.join(dir, "scarpe-launcher")
    libs = %w[lib lacci/lib scarpe-components/lib].map { |lib| "-I #{Shellwords.escape(File.join(ROOT, lib))}" }
    File.write(path, <<~SH)
      #!/bin/sh
      export LAUNCHED_BY="$0"
      exec #{Shellwords.escape(RbConfig.ruby)} #{libs.join(" ")} #{Shellwords.escape(SCARPE)} --native "$SCARPE_RUN_FILE"
    SH
    File.chmod(0o755, path)
  end

  def until_true(seconds)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    until (answer = yield)
      return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
    answer
  end

  # Running, and not a zombie waiting for a parent to reap it.
  def alive?(pid)
    stat = `ps -o stat= -p #{Integer(pid)}`.strip
    !stat.empty? && !stat.start_with?("Z")
  end
end
