# frozen_string_literal: true

require_relative "helper"

# Real Lacci apps through exe/scarpe --native, with the fake child in Rust's seat.
class AppTest < Minitest::Test
  include NativeTestHelpers

  CLOSE_ON_RUN = [{ "on" => "run", "emit" => [{ "t" => "closed", "app" => "first" }] }].freeze

  def test_hello_world_create_sequence
    run = run_app(<<~RUBY, script: CLOSE_ON_RUN)
      Shoes.app(title: "Hello") { para "Hello" }
    RUBY
    assert_clean_exit(run)

    assert_equal "hello", run.received.first["t"]
    root, app, para = run.creates
    assert_equal({ "id" => 2, "kind" => "DocumentRoot", "parent" => nil }, root.slice("id", "kind", "parent"))
    assert_equal({ "id" => 1, "kind" => "App", "doc_root" => 2, "owner" => nil }, app.slice("id", "kind", "doc_root", "owner"))
    assert_equal({ "title" => "Hello", "width" => 600, "height" => 500 }, app["props"].slice("title", "width", "height"))
    assert_equal({ "kind" => "Para", "parent" => 2, "index" => nil }, para.slice("kind", "parent", "index"))
    assert_equal ["Hello"], para["props"]["text_items"]
    refute para["props"].key?("shoes_linkable_id")

    types = run.received.map { |message| message["t"] }
    assert_equal ["run", "flush"], types[types.index("run"), 2], "the first batch ends at run"
    assert_equal({ "t" => "run", "app" => 1 }, run.of_type("run").first)
    assert_equal "quit", types.last
  end

  def test_button_click_runs_the_ruby_handler_and_the_change_goes_back_as_props
    run = run_app(<<~RUBY, script: [
      Shoes.app do
        @p = para "Waiting"
        button("Go") { @p.replace("clicked"); puts "handler ran" }
      end
    RUBY
      { "on" => "run", "emit" => [{ "t" => "event", "name" => "click", "target" => { "kind" => "Button" }, "args" => [] }] },
      { "on" => "props", "after" => 0.05, "emit" => [{ "t" => "closed", "app" => "first" }] },
    ])
    assert_clean_exit(run)
    assert_equal "handler ran\n", run.stdout
    para_id = run.creates("Para").first["id"]
    assert_equal [{ "t" => "props", "id" => para_id, "props" => { "text_items" => ["clicked"] } }], run.of_type("props")
  end

  def test_create_props_are_normalized
    run = run_app(<<~RUBY, script: CLOSE_ON_RUN)
      Shoes.app do
        background "#DFA".."#000"
        stack(attach: Window) { border red, strokewidth: 2 }
        image "cat.png"
        para "hi", stroke: rgb(0.5, 0.5, 0.5)
        link("home") { }
      end
    RUBY
    assert_clean_exit(run)
    assert_equal({ "gradient" => [{ "rgba" => [221, 255, 170, 255] }, { "rgba" => [0, 0, 0, 255] }], "angle" => 0 },
      run.creates("Background").first["props"]["fill"])
    assert_equal "window", run.creates("Stack").first["props"]["attach"]
    assert_equal({ "rgba" => [255, 0, 0, 255] }, run.creates("Border").first["props"]["stroke"])
    assert run.creates("Image").first["props"]["url"].end_with?("/#{File.basename(run.dir)}/cat.png"), "relative to the app"
    assert_equal({ "rgba" => [128, 128, 128, 255] }, run.creates("Para").first["props"]["stroke"])
    assert_equal true, run.creates("Link").first["props"]["has_block"]
  end

  def test_prepend_sends_the_position
    run = run_app(<<~RUBY, script: CLOSE_ON_RUN)
      Shoes.app do
        @s = stack { para "b"; para "c" }
        @s.prepend { para "a" }
      end
    RUBY
    assert_clean_exit(run)
    stack_id = run.creates("Stack").first["id"]
    prepended = run.creates("Para").find { |para| para["props"]["text_items"] == ["a"] }
    assert_equal({ "parent" => stack_id, "index" => 0 }, prepended.slice("parent", "index"))
  end

  def test_ruby_timers_fire_at_the_right_counts_in_real_time
    run = run_app(<<~RUBY)
      Shoes.app do
        frames = []
        counts = []
        animate(40) { |frame| frames << frame }
        every(0.05) { |count| counts << count }
        timer(0.4) do
          puts frames.inspect
          puts counts.inspect
          Shoes.quit
        end
      end
    RUBY
    assert_clean_exit(run)
    # Counted from 0, one at a time, on the real clock. How many fit in 0.4 s is how often the
    # machine wakes a sleeping process: a macOS runner fired 4 frames where 16 were due, as this
    # Mac does under `taskpolicy -c background`, and a late timer skips the frames it missed.
    frames, counts = run.stdout.lines.map { |line| JSON.parse(line) }
    assert_equal (0...frames.size).to_a, frames, "animate counts frames from 0, one at a time"
    assert_operator frames.size, :>=, 2, run.stdout
    assert_equal (0...counts.size).to_a, counts, "every counts from 0"
    assert_operator counts.size, :>=, 2, run.stdout
  end

  def test_a_raising_handler_is_logged_and_the_loop_keeps_going
    run = run_app(<<~RUBY, script: [
      Shoes.app do
        button("boom") { raise "kaboom" }
        button("fine") { puts "still alive"; Shoes.quit }
      end
    RUBY
      { "on" => "run", "emit" => [
        { "t" => "event", "name" => "click", "target" => { "text" => "boom" }, "args" => [] },
        { "t" => "event", "name" => "click", "target" => { "text" => "fine" }, "args" => [] },
      ] },
    ])
    assert_clean_exit(run)
    assert_equal "still alive\n", run.stdout
    assert_match(/RuntimeError: kaboom in the click handler for 3 \(at .*app\.rb:2/, run.stderr)
  end

  # A failed require, a runaway recursion or NotImplementedError are not StandardErrors, but a bad
  # block is a bad block: logged, and the app carries on (review).
  def test_a_handler_that_raises_beyond_standard_error_is_logged_and_the_loop_keeps_going
    clicks = %w[require recurse unimplemented fine].map do |text|
      { "t" => "event", "name" => "click", "target" => { "text" => text }, "args" => [] }
    end
    run = run_app(<<~RUBY, script: [{ "on" => "run", "emit" => clicks }])
      Shoes.app do
        button("require") { require "definitely_not_a_gem_xyz" }
        button("recurse") { recurse = ->(depth) { recurse.(depth + 1) }; recurse.(0) }
        button("unimplemented") { raise NotImplementedError, "not yet" }
        button("fine") { puts "still alive"; Shoes.quit }
      end
    RUBY
    assert_clean_exit(run)
    assert_equal "still alive\n", run.stdout
    assert_match(/LoadError: cannot load such file -- definitely_not_a_gem_xyz in the click handler/, run.stderr)
    assert_match(/SystemStackError: stack level too deep in the click handler/, run.stderr)
    assert_match(/NotImplementedError: not yet in the click handler/, run.stderr)
  end

  # Inside an app `exit` is Shoes' own quit; Kernel.exit raises SystemExit, which still ends it.
  def test_kernel_exit_in_a_handler_still_ends_the_app
    run = run_app(<<~RUBY, script: [{ "on" => "run", "emit" => [{ "t" => "event", "name" => "click", "target" => { "kind" => "Button" }, "args" => [] }] }])
      Shoes.app { button("bye") { Kernel.exit(3) } }
    RUBY
    refute run.timed_out
    assert_equal 3, run.status.exitstatus
  end

  def test_a_child_crash_is_reported_with_its_stderr
    run = run_app(<<~RUBY, script: [{ "on" => "run", "crash" => "thread 'main' panicked at src/paint.rs:7:5" }])
      Shoes.app { para "hi" }
    RUBY
    refute run.timed_out
    refute run.status.success?
    assert_match(/scarpe-native \(pid \d+\) exited with status 101/, run.stderr)
    assert_match(%r{The end of its stderr:.*\nthread 'main' panicked at src/paint.rs:7:5}, run.stderr)
  end

  # Shoes 3 sends every slot its finish as the window closes: the window's own slot first
  # (shoes_app_remove, s3_app.c:107-114), then each slot as it is removed, after its children
  # (s3_canvas.c:481-495), hidden ones too. Hackety Hack saves the child's program from there,
  # so closing its window with the red button lost the program.
  def test_closing_a_window_sends_every_slot_its_finish
    run = run_app(<<~RUBY, script: CLOSE_ON_RUN)
      Shoes.app do
        finish { puts "the window's own slot" }
        @side = stack(hidden: true) do
          stack { finish { puts "inside it" } }
        end
        @side.finish { |slot| puts "the hidden stack, handed a \#{slot.class}" }
      end
    RUBY
    assert_clean_exit(run)
    assert_equal "the window's own slot\ninside it\nthe hidden stack, handed a Shoes::Stack\n", run.stdout
  end

  def test_an_app_that_closes_itself_finishes_its_slots_once
    run = run_app(<<~RUBY)
      Shoes.app do
        stack { finish { puts "finished" } }
        timer(0.05) { close }
      end
    RUBY
    assert_clean_exit(run)
    assert_equal "finished\n", run.stdout
  end

  def test_a_child_that_closes_its_last_window_and_exits_has_not_crashed
    run = run_app(<<~RUBY, script: [{ "on" => "run", "emit" => [{ "t" => "closed", "app" => "first" }], "exit" => 0 }])
      Shoes.app { para "hi" }
      sleep 0.2 # the child is long gone before the pump reads its last words
    RUBY
    assert_clean_exit(run)
  end

  def test_builtin_round_trip_queues_events_until_the_answer_arrives
    run = run_app(<<~RUBY, headless: false, script: [
      Shoes.app do
        button("b") { puts "clicked" }
        puts "answer: \#{ask("Your name?")}"
        puts "confirm: \#{confirm("Sure?").inspect}"
        timer(0.1) { Shoes.quit }
      end
    RUBY
      { "on" => "req:dialog", "match" => { "kind" => "ask" }, "reply" => "Nick",
        "emit" => [{ "t" => "event", "name" => "click", "target" => { "kind" => "Button" }, "args" => [] }] },
    ])
    assert_clean_exit(run)
    assert_equal ["answer: Nick", "confirm: true", "clicked"], run.stdout.lines.map(&:chomp)
    dialogs = run.of_type("req").select { |req| req["op"] == "dialog" }
    assert_equal([["ask", "Your name?"], ["confirm", "Sure?"]], dialogs.map { |req| [req["kind"], req["message"]] })
  end

  # Ledger K1: ask takes secret: and title: (manual 1385-1391, Shoes 3 s3_gtk.c:1772-1826); Lacci
  # hands them over beside the message, and they reach Rust with the dialog.
  def test_ask_hands_its_secret_and_title_to_the_dialog
    run = run_app(<<~RUBY, headless: false, script: [{ "on" => "req:dialog", "reply" => "hunter2" }])
      Shoes.app do
        puts ask("Password?", secret: true, title: "Log in")
        timer(0.05) { Shoes.quit }
      end
    RUBY
    assert_clean_exit(run)
    assert_equal "hunter2\n", run.stdout
    dialog = run.of_type("req").find { |req| req["op"] == "dialog" }
    assert_equal({ "kind" => "ask", "message" => "Password?", "secret" => true, "title" => "Log in" },
      dialog.slice("kind", "message", "secret", "title"))
  end

  def test_a_cancelled_file_dialog_is_nil_and_never_falls_back_to_osascript
    run = run_app(<<~RUBY, headless: false, script: [{ "on" => "req:dialog", "reply" => nil }])
      puts ask_open_file.inspect
      Shoes.app { timer(0.05) { Shoes.quit } }
    RUBY
    assert_clean_exit(run)
    assert_equal "nil\n", run.stdout
  end

  # Ledger K1, ruled 27 Sep 2026 (Q6): a cancelled ask answers "", as Nick's commit 6ce3d28 made
  # the webview do, so legacy scripts can compare the answer without checking for nil.
  def test_a_cancelled_ask_is_an_empty_string
    run = run_app(<<~RUBY, headless: false, script: [{ "on" => "req:dialog", "match" => { "kind" => "ask" }, "reply" => nil }])
      Shoes.app do
        puts ask("Your name?").inspect
        timer(0.05) { Shoes.quit }
      end
    RUBY
    assert_clean_exit(run)
    assert_equal "\"\"\n", run.stdout
  end

  def test_headless_dialogs_answer_quietly_without_asking_the_child
    run = run_app(<<~RUBY)
      Shoes.app do
        p [ask("q"), confirm("c"), alert("a"), ask_color("t"), ask_open_file, ask_save_folder]
        Shoes.quit
      end
    RUBY
    assert_clean_exit(run)
    assert_equal "[\"\", false, nil, nil, nil, nil]\n", run.stdout
    assert_empty run.of_type("req")
  end

  def test_font_sends_an_absolute_path
    run = run_app(<<~RUBY, script: CLOSE_ON_RUN) do |dir|
      font "fonts/Fancy.ttf"
      Shoes.app { para "hi" }
    RUBY
      # font reads the family names out of the file, so it has to be a real font (ledger K4).
      FileUtils.mkdir_p(File.join(dir, "fonts"))
      FileUtils.cp(File.expand_path("../../fonts/Pacifico.ttf", __dir__), File.join(dir, "fonts", "Fancy.ttf"))
    end
    assert_clean_exit(run)
    path = run.of_type("font").first["path"]
    assert File.absolute_path?(path), path
    assert path.end_with?("/fonts/Fancy.ttf")
  end

  def test_list_box_choice_comes_back_as_the_original_item
    run = run_app(<<~RUBY, script: [
      Shoes.app do
        list_box(items: [1, 2, 3]) { |box| p box.chosen; Shoes.quit }
      end
    RUBY
      { "on" => "run", "emit" => [{ "t" => "event", "name" => "change", "target" => { "kind" => "ListBox" }, "args" => ["2"] }] },
    ])
    assert_clean_exit(run)
    assert_equal "2\n", run.stdout
  end

  def test_a_second_window_outlives_the_first
    run = run_app(<<~RUBY, script: [
      Shoes.app do
        button("new") { window(title: "two") { para "second" } }
      end
    RUBY
      { "on" => "run", "match" => { "app" => 1 }, "emit" => [{ "t" => "event", "name" => "click", "target" => { "kind" => "Button" }, "args" => [] }] },
      { "on" => "run", "match" => { "app" => 4 }, "emit" => [{ "t" => "closed", "app" => 1 }] },
      { "on" => "run", "match" => { "app" => 4 }, "after" => 0.2, "emit" => [{ "t" => "closed", "app" => 4 }] },
    ])
    assert_clean_exit(run)
    assert_equal([1, 4], run.of_type("run").map { |message| message["app"] })
    assert_equal 1, run.creates("App").last["owner"]
    assert_equal [{ "t" => "quit", "app" => 1 }, { "t" => "quit", "app" => nil }], run.of_type("quit"),
      "Rust frees the first window as it closes, and everything at the end"
  end

  # A closed window's app is done with: Rust frees its view and document, and it leaves
  # Shoes.APPS (manual 887-888), while the app goes on in the other window (review, ledger A8).
  def test_closing_one_of_two_windows_frees_it_and_the_app_goes_on
    run = run_app(<<~RUBY, script: [
      Shoes.app do
        button("new") { window(title: "two") { para "second" } }
        button("titles") { p Shoes.APPS.map { |app| app.style[:title] } }
      end
    RUBY
      { "on" => "run", "match" => { "app" => 1 }, "emit" => [{ "t" => "event", "name" => "click", "target" => { "text" => "new" }, "args" => [] }] },
      { "on" => "run", "match" => { "app" => 5 }, "emit" => [
        { "t" => "closed", "app" => 5 },
        { "t" => "event", "name" => "click", "target" => { "text" => "titles" }, "args" => [] },
        { "t" => "closed", "app" => 1 },
      ] },
    ])
    assert_clean_exit(run)
    assert_equal "[\"Shoes\"]\n", run.stdout
    assert_equal [{ "t" => "quit", "app" => 5 }, { "t" => "quit", "app" => nil }], run.of_type("quit")
  end

  # Manual 901-904: close "Closes the app window"; exit is for closing the whole application.
  def test_close_in_a_window_closes_that_window_only
    run = run_app(<<~RUBY, script: [
      Shoes.app do
        button("new") { window(title: "two") { button("bye") { close } } }
        button("count") { p Shoes.APPS.size }
      end
    RUBY
      { "on" => "run", "match" => { "app" => 1 }, "emit" => [{ "t" => "event", "name" => "click", "target" => { "text" => "new" }, "args" => [] }] },
      { "on" => "run", "match" => { "app" => 5 }, "emit" => [
        { "t" => "event", "name" => "click", "target" => { "text" => "bye" }, "args" => [] },
      ] },
      { "on" => "quit", "match" => { "app" => 5 }, "emit" => [
        { "t" => "event", "name" => "click", "target" => { "text" => "count" }, "args" => [] },
        { "t" => "closed", "app" => 1 },
      ] },
    ])
    assert_clean_exit(run)
    assert_equal "1\n", run.stdout, "the first window stayed open"
    assert_equal [{ "t" => "quit", "app" => 5 }, { "t" => "quit", "app" => nil }], run.of_type("quit")
  end

  # A window whose block raises was created but never run. It must not count as open, or closing
  # the one real window leaves the pump waiting on it forever (review).
  def test_a_window_whose_block_raises_is_dropped_and_never_counted_as_open
    run = run_app(<<~RUBY, timeout: 8, script: [
      Shoes.app do
        button("broken") { window(title: "broken") { para "about to fail"; raise "typo in the window block" } }
        button("count") { puts Shoes.APPS.size }
      end
    RUBY
      { "on" => "run", "emit" => [{ "t" => "event", "name" => "click", "target" => { "text" => "broken" }, "args" => [] }] },
      { "on" => "create", "match" => { "kind" => "Para" }, "after" => 0.1, "emit" => [
        { "t" => "event", "name" => "click", "target" => { "text" => "count" }, "args" => [] },
        { "t" => "closed", "app" => 1 },
      ] },
    ])
    assert_clean_exit(run)
    assert_match(/RuntimeError: typo in the window block in the click handler/, run.stderr)
    assert_equal "1\n", run.stdout, "the broken window left Shoes.APPS"
    broken = run.creates("App").last["id"]
    assert_includes run.of_type("quit"), { "t" => "quit", "app" => broken }, "and Rust was told to free it"
    assert_equal [1], run.of_type("run").map { |message| message["app"] }
  end

  def test_an_app_nested_in_another_apps_body_shows_both
    run = run_app(<<~RUBY, script: [{ "on" => "run", "match" => { "app" => 1 }, "emit" => [{ "t" => "closed", "app" => 3 }, { "t" => "closed", "app" => 1 }] }])
      Shoes.app do
        Shoes.app { para "inner" }
      end
    RUBY
    assert_clean_exit(run)
    assert_equal([3, 1], run.of_type("run").map { |message| message["app"] })
  end

  def test_a_script_that_raises_after_shoes_app_exits_without_running
    run = run_app(<<~RUBY)
      Shoes.app { para "hi" }
      raise "after the app"
    RUBY
    refute run.timed_out
    refute run.status.success?
    assert_match(/after the app/, run.stderr)
  end

  def test_a_raise_in_the_app_body_ends_the_process
    run = run_app(<<~RUBY)
      Shoes.app { para "hi"; raise "in the body" }
    RUBY
    refute run.timed_out
    refute run.status.success?
    assert_match(/in the body/, run.stderr)
  end

  def test_ctrl_c_quits_the_child_and_exits
    skip_on_windows("a console's Ctrl-C reaches a process group, not one pid")
    run = run_app(<<~RUBY, script: [{ "on" => "run", "signal_parent" => "INT" }])
      Shoes.app { para "hi" }
    RUBY
    assert_clean_exit(run)
    assert_equal [{ "t" => "quit", "app" => nil }], run.of_type("quit")
  end

  def test_peek_clicks_prints_layout_and_saves_a_shot
    shot = ->(app) { File.join(File.dirname(app), "out.png") }
    run = run_app(<<~RUBY, argv: ->(app) { ["peek", app, "--click", "Go", "--layout", "--shot", shot.call(app)] })
      Shoes.app do
        @p = para "Waiting"
        button("Go") { @p.replace("Gone") }
      end
    RUBY
    assert_clean_exit(run)
    lines = run.stdout.lines.map(&:chomp)
    assert_match(/\Aclick "Go" -> #4 at 50,30/, lines[0])
    assert_includes lines, "#3 Para 0,0 100x20 \"Gone\""
    assert_includes lines, "#4 Button 0,20 100x20 \"Go\""
    assert_match(%r{\Ashot (?:[A-Z]:)?/.*/#{File.basename(run.dir)}/out\.png \(600x500\)\z}, lines.last)
  end

  def test_peek_waits_in_real_time_and_resizes_first
    run = run_app(<<~RUBY, argv: ->(app) { ["peek", app, "--wait", "0.3", "--layout", "--size", "300x200"] })
      Shoes.app do
        @p = para "start"
        animate(20) { |frame| @p.replace("frame \#{frame}") }
      end
    RUBY
    assert_clean_exit(run)
    # Frames moved on during the wait. How far is the machine's timer precision, not ours
    # (test_ruby_timers_fire_at_the_right_counts_in_real_time): throttled, this Mac showed frame 1.
    frame = run.stdout[/"frame (\d+)"/, 1]
    assert frame, run.stdout
    assert_operator frame.to_i, :>=, 1, run.stdout
    resize = run.of_type("req").find { |req| req["op"] == "resize" }
    assert_equal({ "w" => 300, "h" => 200 }, resize.slice("w", "h"))
    assert_operator run.received.index(resize), :<, run.received.index(run.of_type("req").find { |req| req["op"] == "layout" })
  end

  def test_peek_looks_once_the_slots_have_started
    run = run_app(<<~RUBY, argv: ->(app) { ["peek", app, "--layout"] })
      Shoes.app { stack { start { |slot| slot.append { para "started" } } } }
    RUBY
    assert_clean_exit(run)
    assert_includes run.stdout, "\"started\"", "what the start block drew is in the layout"
  end

  def test_peek_with_nothing_to_do_saves_peek_png_here
    run = run_app("Shoes.app { para 'hi' }", argv: ->(app) { ["peek", app, "--size", "300x200"] })
    assert_clean_exit(run)
    assert_match(%r{\Ashot (?:[A-Z]:)?/.*/#{File.basename(run.dir)}/peek\.png \(300x200\)\n\z}, run.stdout)
  end

  def test_peek_reports_a_missed_click
    run = run_app("Shoes.app { para 'hi' }", argv: ->(app) { ["peek", app, "--click", "Nope"] })
    refute run.status.success?
    assert_match(/peek: click failed: nothing to click/, run.stderr)
  end

  def test_rake_test_glob_leaves_native_tests_alone
    assert_empty Dir[File.join(ROOT, "test", "native", "**", "test_*.rb")]
  end
end
