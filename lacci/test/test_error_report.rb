# frozen_string_literal: true

require_relative "test_helper"

# Shoes.on_error and the Hash every error arrives as (ledger K9): plain data with String keys,
# which a program in a process of its own can send its parent as JSON.
class TestErrorReport < Minitest::Test
  def setup
    @hooks = Shoes.error_hooks.dup
    Shoes::Console.clear! # other tests share this process's console
  end

  def teardown
    Shoes.error_hooks.replace(@hooks)
    Shoes::Console.clear!
  end

  def raise_in_a_program
    raise ArgumentError, "the flux capacitor jammed"
  rescue => e
    e
  end

  def test_an_error_becomes_plain_data
    error = raise_in_a_program
    err = Shoes::ErrorReport.from(error, during: "handler")
    assert_equal %w[class message backtrace path line during], err.keys
    assert_equal ["ArgumentError", "the flux capacitor jammed", "handler"], err.values_at("class", "message", "during")
    assert_equal File.expand_path(__FILE__), err["path"], "the innermost frame outside Scarpe's own code"
    assert_equal method(:raise_in_a_program).source_location[1] + 1, err["line"], "the line that raised"
    assert(err["backtrace"].all?(String))
    assert_equal err, JSON.parse(JSON.generate(err)), "it survives a trip through JSON"
  end

  def test_during_is_one_of_four
    assert_raises(ArgumentError) { Shoes::ErrorReport.from(RuntimeError.new("x"), during: "lunch") }
    %w[startup handler timer exit].each { |during| assert_equal during, Shoes::ErrorReport.from(RuntimeError.new("x"), during: during)["during"] }
  end

  def test_a_syntax_error_names_the_file_and_line_ruby_gives
    Dir.mktmpdir do |dir|
      path = File.join(dir, "broken.rb")
      File.write(path, "Shoes.app do\n  para 'x'\n")
      error = begin
        load path
      rescue SyntaxError => e
        e
      end
      err = Shoes::ErrorReport.from(error, during: "startup", program: path)
      assert_equal ["SyntaxError", path, "startup"], err.values_at("class", "path", "during")
      assert_kind_of Integer, err["line"]
    end
  end

  # "path" and "line" prefer the program's own frame, however its path is spelled. On a Mac
  # /var and /tmp are links into /private, and Ruby names a loaded file by its real path.
  def test_the_program_frame_is_found_through_a_link_in_its_path
    Dir.mktmpdir do |real|
      Dir.mktmpdir do |links|
        File.write(File.join(real, "helper.rb"), "module ErrorReportLinkedHelper\n  def self.go\n    raise 'the helper broke'\n  end\nend\n")
        File.write(File.join(real, "program.rb"), "require_relative 'helper'\nErrorReportLinkedHelper.go\n")
        File.symlink(real, File.join(links, "linked"))
        program = File.join(links, "linked", "program.rb")
        error = begin
          load program
        rescue RuntimeError => e
          e
        end
        err = Shoes::ErrorReport.from(error, during: "startup", program: program)
        assert_equal [File.realpath(program), 2], [File.realpath(err["path"]), err["line"]], "the program's line, not its helper's"
      end
    end
  end

  def test_an_error_with_no_backtrace_has_no_place
    err = Shoes::ErrorReport.from(RuntimeError.new("made, never raised"), during: "exit")
    assert_equal [nil, nil, []], err.values_at("path", "line", "backtrace")
  end

  def test_a_message_that_is_not_utf8_still_travels
    error = RuntimeError.new("caf\xE9".b)
    assert JSON.generate(Shoes::ErrorReport.from(error, during: "handler"))
  end

  def test_report_error_lists_it_and_tells_every_block
    heard = []
    Shoes.on_error { |err| heard << [:first, err["message"]] }
    Shoes.on_error { |_err| raise "a hook that breaks" }
    Shoes.on_error { |err| heard << [:third, err["during"]] }
    err = Shoes.report_error(raise_in_a_program, during: "timer")

    assert_equal [[:first, "the flux capacitor jammed"], [:third, "timer"]], heard, "a hook that raises stops no other"
    assert_equal "timer", err["during"]
    entry = Shoes::Console.entries.reverse.find { |e| e.message.include?("the flux capacitor jammed") }
    refute_nil entry, "the console lists it"
    assert_equal :error, entry.level
    assert_includes entry.where, "in a timer"
  end

  def test_on_error_needs_a_block
    assert_raises(ArgumentError) { Shoes.on_error }
  end

  # An error that stops a file loading reaches Shoes.on_error as "startup", and goes on up.
  def test_run_app_reports_a_startup_error
    heard = []
    Shoes.on_error { |err| heard << err }
    Dir.mktmpdir do |dir|
      path = File.join(dir, "app.rb")
      File.write(path, "x = 1\nraise NameError, 'nobody named this'\n")
      here = Dir.pwd
      begin
        assert_raises(NameError) { Shoes.run_app(path) }
      ensure
        Dir.chdir(here)
      end
      assert_equal 1, heard.size
      assert_equal ["NameError", "startup", 2], heard.first.values_at("class", "during", "line")
      assert_equal File.realpath(path), File.realpath(heard.first["path"])
    end
  end

  def test_run_app_runs_in_the_dir_it_is_given
    Dir.mktmpdir do |dir|
      Dir.mkdir(File.join(dir, "elsewhere"))
      path = File.join(dir, "app.rb")
      File.write(path, "$ran_in = Dir.pwd\n")
      here = Dir.pwd
      begin
        Shoes.run_app(path, dir: File.join(dir, "elsewhere"))
      ensure
        Dir.chdir(here)
      end
      assert_equal File.realpath(File.join(dir, "elsewhere")), File.realpath($ran_in)
    end
  end
end
