# frozen_string_literal: true

require_relative "helper"

# Shoes-Spec on the native backend: test code runs in the app's process, clicks go through the
# (fake) Rust child, results come back through SHOES_MINITEST_EXPORT_FILE like Niente's.
class SpecTest < Minitest::Test
  include NativeTestHelpers

  def test_finders_and_trigger_click_through_the_child
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @p = para "Waiting"
        button("Go") { @p.replace("Gone") }
        button("Other") {}
      end
    APP
      button("Go").trigger_click
      assert_equal "Gone", para.text
      assert_equal 2, buttons.size
      assert_equal "Other", find_button("Other").text
      assert_equal 1, all_paras.size
    TEST
    assert_spec_passed(run)
    go = run.creates("Button").first["id"]
    assert_includes run.of_type("req"), { "t" => "req", "req" => 2, "op" => "click", "target" => { "id" => go }, "button" => 1, "app" => 1 }
    assert_equal "NativeSpec", run.result["klass"]
    assert_equal "test_native", run.result["name"]
  end

  def test_tests_start_after_the_first_frame
    run = run_app("Shoes.app { para 'hi' }", test_code: "assert true")
    assert_spec_passed(run)
    first_req = run.of_type("req").first
    assert_equal({ "op" => "frames", "n" => 1 }, first_req.slice("op", "n"))
    assert run.received.index(first_req) > run.received.index(run.of_type("run").first)
  end

  # Lacci runs a slot's start blocks on the first heartbeat, so test code runs once that heartbeat's
  # handlers are done: before, it ran first, and no slot had started (ledger H8, events.start).
  def test_tests_run_after_the_first_heartbeat_has_started_the_slots
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app do
        $started = []
        stack { start { |slot| $started << slot.linkable_id } }
      end
    APP
      assert_equal [stack.linkable_id], $started
    TEST
    assert_spec_passed(run)
  end

  # A slot made while test code runs starts on the next heartbeat, which wait_frames beats as the
  # pump would.
  def test_a_slot_made_by_test_code_starts_by_the_next_frame
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app do
        $started = []
        button("more") { stack { start { $started << :more } } }
      end
    APP
      click_on "more"
      assert_empty $started, "a slot starts once it has been drawn, not when it is made"
      wait_frames
      assert_equal [:more], $started
    TEST
    assert_spec_passed(run)
  end

  def test_failures_are_exported_and_the_process_still_exits
    run = run_app("Shoes.app { para 'hi' }", test_code: "assert_equal 'bye', para.text")
    assert_clean_exit(run)
    failure = JSON.parse(run.result["failures"].first[1])
    assert_equal "Minitest::Assertion", failure["json_class"]
    assert_match(/Expected: "bye"/, failure["m"])
  end

  def test_typing_into_the_focused_edit_line
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @p = para ""
        @e = edit_line { @p.replace(@e.text) }
      end
    APP
      assert_nil focused_drawable
      click_on(edit_line)
      assert_equal edit_line.linkable_id, focused_drawable.linkable_id
      type_text("hi")
      assert_equal "hi", edit_line.text
      assert_equal "hi", para.text
    TEST
    assert_spec_passed(run)
    edit_id = run.creates("EditLine").first["id"]
    assert_includes run.of_type("props"), { "t" => "props", "id" => edit_id, "props" => { "text" => "hi" } }
  end

  def test_hover_and_leave_through_the_pointer
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @b = button("B")
        @b.hover { $seen << :hover }
        @b.leave { $seen << :leave }
        $seen = []
      end
    APP
      button.trigger_hover
      assert_equal [:hover], $seen
      button.trigger_leave
      assert_equal [:hover, :leave], $seen
    TEST
    assert_spec_passed(run)
  end

  def test_advance_fires_timers_exactly
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app do
        $frames = []
        $counts = []
        $fired = []
        @anim = animate(10) { |frame| $frames << frame }
        every(0.25) { |count| $counts << count }
        timer(0.55) { $fired << $frames.size }
      end
    APP
      assert_empty $frames, "nothing fires until the test moves the clock"
      advance(1.0)
      assert_equal (0..9).to_a, $frames
      assert_equal [0, 1, 2, 3], $counts
      assert_equal [5], $fired

      subscription_item("@anim").stop
      advance(1.0)
      assert_equal 10, $frames.size, "stopped"
      subscription_item("@anim").start
      advance(0.1)
      assert_equal (0..10).to_a, $frames
    TEST
    assert_spec_passed(run)
  end

  def test_timers_created_in_a_handler
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app do
        $ticks = []
        button("start") { every(0.1) { |count| $ticks << count } }
      end
    APP
      click_on("start")
      advance(0.3)
      assert_equal [0, 1, 2], $ticks
    TEST
    assert_spec_passed(run)
  end

  def test_layout_snapshot_pixel_and_resize
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app do
        para "top"
        button "B"
      end
    APP
      assert_equal Scarpe::Native::Rect.new(0, 20, 100, 20), layout_of(button)
      assert_equal Scarpe::Native::Rect.new(0, 20, 100, 20), button.layout
      assert_equal %w[Para Button], layout_tree.map { |node| node[:kind] }
      path = snapshot("home")
      assert path.end_with?("/snapshots/home.png")
      assert File.exist?(path)
      assert_equal [255, 255, 255, 255], pixel_at(1, 1)
      resize_window(640, 500)
      assert_equal [640, 500], [Shoes.APPS.first.width, Shoes.APPS.first.height]
      wait_frames(2)
    TEST
    assert_spec_passed(run)
    assert_equal({ "op" => "frames", "n" => 2 }, run.of_type("req").last.slice("op", "n"))
  end

  def test_dialogs_are_stubbed_or_quiet_even_when_windowed
    run = run_app(<<~APP, headless: false, test_code: <<~TEST)
      Shoes.app do
        button("ask") { $answer = ask("Name?") }
        button("alert") { alert("Hi") }
      end
    APP
      stub_dialog(:ask, "Nick")
      click_on("ask")
      assert_equal "Nick", $answer
      click_on("ask")
      assert_equal "", $answer, "unstubbed dialogs answer quietly under Shoes-Spec"
      stub_confirm(returns: true)
      assert_equal true, confirm("sure?")
      click_on("alert")
      assert_equal [["ask", "Name?"], ["ask", "Name?"], ["confirm", "sure?"], ["alert", "Hi"]], dialogs_seen
    TEST
    assert_spec_passed(run)
    assert_empty(run.of_type("req").select { |req| req["op"] == "dialog" })
  end

  def test_messages_from_rust_update_lacci
    run = run_app(<<~APP, script: [{ "on" => "run", "emit" => [
      Shoes.app do
        stack { para "text" }
      end
    APP
      { "t" => "resize", "app" => "first", "w" => 640, "h" => 500 },
      { "t" => "mouse", "state" => [1, 5, 6] },
      { "t" => "para_hit", "id" => { "kind" => "Para" }, "value" => 3 },
      { "t" => "scroll", "id" => { "kind" => "Stack" }, "top" => 40 },
    ] }], test_code: <<~TEST)
      app = Shoes.APPS.first
      assert_equal [640, 500], [app.width, app.height]
      assert_equal [1, 5, 6], app.mouse
      assert_equal 3, para.hit(0, 0)
      assert_equal 40, stack.scroll_top
    TEST
    assert_spec_passed(run)
    refute_includes run.of_type("props").map { |message| message["props"].keys }.flatten, "width", "resize must not echo"
  end

  def test_change_keypress_and_triggers
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app do
        $keys = []
        $wheels = []
        list_box(items: ["a", "b"])
        keypress { |key| $keys << key }
        wheel { |delta, x, y| $wheels << [delta, x, y] }
        button("at") { $clicked = true }
      end
    APP
      list_box.trigger_change("b")
      assert_equal "b", list_box.chosen
      press_key("left")
      press_key("a")
      assert_includes $keys, :left
      assert_includes $keys, "a"
      wheel(-3, x: 10, y: 12)
      wheel(1)
      assert_equal [[-3, 10, 12], [1, 300.0, 250.0]], $wheels
      click_at(50, 30)
      assert $clicked
    TEST
    assert_spec_passed(run)
  end

  def test_changes_made_in_test_code_reach_the_child
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app do
        para "gone soon"
        button "wide"
      end
    APP
      button.style(width: 200)
      para.remove
      wait_frames
      assert true
    TEST
    assert_spec_passed(run)
    para_id = run.creates("Para").first["id"]
    button_id = run.creates("Button").first["id"]
    assert_includes run.of_type("props"), { "t" => "props", "id" => button_id, "props" => { "width" => 200 } }
    assert_includes run.of_type("destroy"), { "t" => "destroy", "id" => para_id }
  end

  def test_the_shim_listens_once_per_event_not_once_per_drawable
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app { 50.times { |i| para "p\#{i}" } }
    APP
      handlers = Shoes::DisplayService.class_variable_get(:@@display_event_handlers)
      ids = paras.map(&:linkable_id)
      per_drawable = %w[prop_change destroy parent focus scroll_top].sum do |name|
        (handlers[name] || {}).values_at(*ids).compact.sum(&:size)
      end
      assert_equal 0, per_drawable, "Lacci's unsubscribe scans them all, so clearing a big slot went quadratic"
    TEST
    assert_spec_passed(run)
  end

  def test_children_land_where_lacci_put_them
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @s = stack { @b = para "b"; para "d" }
        @s.prepend { para "a1"; para "a2" }
        @s.after(@b) { para "c" }
        @s.before(@b) { para "a3" }
      end
    APP
      texts = layout_tree.select { |node| node[:kind] == "Para" }.map { |node| node[:text] }
      assert_equal stack.contents.map(&:text), texts
      assert_equal %w[a1 a2 a3 b c d], texts
    TEST
    assert_spec_passed(run)
  end

  def test_display_mirrors_what_rust_was_told
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @s = stack { button "B" }
        @box = list_box(items: %w[a b c])
      end
    APP
      assert_equal "Stack", button.display.parent.shoes_type
      assert_equal [button.display], stack.display.children
      assert_equal "DocumentRoot", stack.display.parent.kind
      list_box.choose("c")
      assert_equal "c", list_box.display.props["chosen"]
      assert_equal "c", list_box.display.instance_variable_get(:@chosen)
    TEST
    assert_spec_passed(run)
  end

  def test_removing_a_slot_stops_the_timers_inside_it
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app do
        $frames = []
        @s = stack { animate(10) { |frame| $frames << frame } }
      end
    APP
      advance(0.2)
      stack.remove
      advance(1.0)
      assert_equal [0, 1], $frames
    TEST
    assert_spec_passed(run)
  end

  def test_a_raising_handler_fails_the_test_that_clicked_it
    run = run_app(<<~APP, test_code: <<~TEST)
      Shoes.app do
        button("boom") { raise ArgumentError, "kaboom" }
        timer(0.5) { raise "late" }
      end
    APP
      error = assert_raises(ArgumentError) { button.trigger_click }
      assert_equal "kaboom", error.message
      assert_raises(RuntimeError) { advance(1) }
    TEST
    assert_spec_passed(run)
  end

  def test_class_names_that_are_not_constants_are_cleaned_up
    run = run_app("Shoes.app { para 'hi' }", test_code: "assert true", env: { "SHOES_MINITEST_CLASS_NAME" => "legacy/shoes-contrib/app" })
    assert_spec_passed(run)
    assert_equal "LegacyShoesContribApp", run.result["klass"]
  end
end
