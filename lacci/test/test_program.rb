# frozen_string_literal: true

require_relative "test_helper"

# Shoes::Program, the handle Shoes.run_program gives back (ledger K10). A display service
# delivers what the program reports on the event loop; a block added late still hears the
# errors so far and the end.
class TestProgramHandle < Minitest::Test
  Driver = Struct.new(:pid, :stops) do
    def stop
      self.stops += 1
    end
  end

  def program
    @driver = Driver.new(4242, 0)
    Shoes::Program.new("/tmp/game.rb", dir: "/tmp", args: ["a"], driver: @driver)
  end

  def test_news_reaches_every_block_in_order
    p = program
    heard = []
    p.on_output { |stream, line| heard << [:output, stream, line] }
    p.on_error { |err| heard << [:error, err["message"]] }
    p.on_exit { |status| heard << [:exit, status] }
    p.deliver_output("stdout", "hi")
    p.deliver_error({ "message" => "boom" })
    p.deliver_exit(:status)
    p.deliver_exit(:again)
    assert_equal [[:output, "stdout", "hi"], [:error, "boom"], [:exit, :status]], heard, "only the first exit counts"
    assert_equal [4242, :status, false], [p.pid, p.status, p.running?]
  end

  def test_a_late_block_hears_what_it_missed
    p = program
    p.deliver_error({ "message" => "one" })
    p.deliver_error({ "message" => "two" })
    errors = []
    p.on_error { |err| errors << err["message"] }
    assert_equal %w[one two], errors
    p.deliver_exit(:done)
    ended = nil
    p.on_exit { |status| ended = status }
    assert_equal :done, ended
  end

  def test_stop_asks_the_driver
    p = program
    assert_same p, p.stop
    assert_equal 1, @driver.stops
  end

  def test_only_so_many_errors_are_kept
    p = program
    (Shoes::Program::KEPT_ERRORS + 3).times { |i| p.deliver_error({ "message" => i.to_s }) }
    errors = []
    p.on_error { |err| errors << err["message"] }
    assert_equal Shoes::Program::KEPT_ERRORS, errors.size
    assert_equal "3", errors.first
  end

  def test_run_program_wants_a_file_that_is_there
    assert_raises(Errno::ENOENT) { Shoes.run_program("/nowhere/at/all.rb") }
  end
end

# Niente cannot start a process, so a program runs inside the app, as Shoes 3's did, and says so.
class TestProgramInProcess < NienteTest
  def test_niente_runs_the_program_inside_and_reports_its_startup_error
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "fine.rb"), "$fine_ran = true\nShoes.app(title: 'the program') { para 'hi' }\n")
      File.write(File.join(dir, "broken.rb"), "x = 1\nraise ArgumentError, 'it broke at the start'\n")
      run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
        Shoes.app { para "the parent" }
      SHOES_APP
        program = Shoes.run_program(#{File.join(dir, "fine.rb").inspect})
        assert $fine_ran, "it ran, here"
        assert_nil program.pid
        refute program.running?
        assert_equal 2, Shoes.APPS.size, "its window opened in this process"
        ended = :not_yet
        program.on_exit { |status| ended = status }
        assert_nil ended, "on_exit hears nil"
        program.stop
        assert_equal 1, Shoes.APPS.size, "stop closes its windows"

        broken = Shoes.run_program(#{File.join(dir, "broken.rb").inspect})
        errors = []
        broken.on_error { |err| errors << err }
        assert_equal [["ArgumentError", "startup", 2]], errors.map { |e| e.values_at("class", "during", "line") }
        assert_equal 1, Shoes.APPS.size, "the parent carries on"
      SHOES_SPEC
    end
  end
end
