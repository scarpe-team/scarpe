# frozen_string_literal: true

require_relative "helper"

# Real Lacci apps through exe/scarpe --native and the real Rust child, headless with bundled fonts.
# Each test drives an app the way a person would (clicks, keys, time passing) through Rust's own
# layout and hit-testing, then checks what Ruby saw and what Rust drew.
class EndToEndTest < Minitest::Test
  include NativeTestHelpers

  def setup
    skip_without_real_binary
  end

  def test_hello_world_draws_its_text
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app { para "Hello World" }
    APP
      text = layout_of(para)
      midline = text.y + text.h / 2
      inked = (0...text.w.to_i).count { |dx| pixel_at(text.x + dx + 0.5, midline).first(3).sum < 3 * 128 }
      assert_operator inked, :>=, 10, "the letters leave dark pixels across the para"
      assert_equal [255, 255, 255, 255], pixel_at(400, 300), "and the rest stays white"
      assert_operator File.size(snapshot("hello_world")), :>, 1000
    TEST
    assert_spec_passed(run)
  end

  def test_rust_pushes_where_things_landed_into_the_layout_cache
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @box = stack(width: 120) { @b = button "B", width: 50, height: 20 }
      end
    APP
      cache = Shoes::DisplayService.layout_cache
      b = button("@b")
      assert_equal layout_of(b).to_a, cache[b.linkable_id].first(4), "the button's rect, as Rust laid it out"
      assert_equal 20, cache[b.linkable_id][4], "an element's scroll height is its height"
      assert_equal [0, 0, 120, 20, 20], cache[stack("@box").linkable_id], "a slot's is its content's"

      id = b.linkable_id
      b.remove
      refute cache.key?(id), "a destroyed drawable leaves the cache"
    TEST
    assert_spec_passed(run)
  end

  def test_short_hex_colours_expand_the_same_on_both_sides
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app { background "#DFA" }
    APP
      assert_equal [221, 255, 170, 255], pixel_at(2, 2), "#DFA is x17 per digit"
    TEST
    assert_spec_passed(run)
  end

  def test_clicking_a_button_runs_its_handler_and_the_para_follows
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @push = button "Push me"
        @note = para "Nothing pushed so far"
        @push.click do
          @note.replace("Aha! Click! ", link("Go back") { @note.replace "Nothing pushed so far" })
        end
      end
    APP
      button.trigger_click
      assert_equal "Aha! Click! Go back", para.text
      shown = layout_tree.find { |node| node[:kind] == "Link" }
      assert_equal "Go back", shown[:text], "Rust laid out the new link"

      click_on("Go back")
      assert_equal "Nothing pushed so far", para.text
    TEST
    assert_spec_passed(run)
  end

  def test_typing_into_an_edit_line_fires_change_with_the_whole_text
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        $changes = []
        @name = edit_line("John", width: "100%")
        @greeting = para "Hello \#{@name.text}!"
        @name.change { $changes << @name.text; @greeting.replace("Hello \#{@name.text}!") }
      end
    APP
      click_on(edit_line)
      press_key("end")
      type_text(" Smith")
      assert_equal "John Smith", $changes.last
      assert_equal ["John ", "John S", "John Sm", "John Smi", "John Smit", "John Smith"], $changes
      assert_equal "Hello John Smith!", para.text
      assert_equal "John Smith", layout_tree.find { |node| node[:kind] == "EditLine" }[:text]
    TEST
    assert_spec_passed(run)
  end

  def test_a_check_toggles_in_lacci_and_rust_draws_the_echo
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @box = check
        @said = para ""
        @box.click { @said.replace(@box.checked? ? "on" : "off") }
      end
    APP
      box = layout_of(check)
      corner = [box.x + 13, box.y + 13]
      assert_equal [255, 255, 255], pixel_at(*corner).first(3)

      check.trigger_click
      assert check.checked?
      assert_equal "on", para.text
      assert_equal [10, 132, 255], pixel_at(*corner).first(3), "accent blue once Lacci echoes checked"

      check.trigger_click
      refute check.checked?
      assert_equal "off", para.text
      assert_equal [255, 255, 255], pixel_at(*corner).first(3)
    TEST
    assert_spec_passed(run)
  end

  def test_picking_from_a_list_box_popup_hands_lacci_the_original_item
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        $picked = []
        list_box(items: [:phyllis, :ronald, :wyatt]) { |box| $picked << box.chosen }
      end
    APP
      assert_nil layout_tree.find { |node| node[:kind] == "ListBox" }[:text], "nothing chosen yet (ledger G3)"
      click_on(list_box)
      click_on("wyatt")
      assert_equal [:wyatt], $picked
      assert_equal :wyatt, list_box.chosen
      assert_equal "wyatt", layout_tree.find { |node| node[:kind] == "ListBox" }[:text]
    TEST
    assert_spec_passed(run)
  end

  def test_animate_moves_the_para_frame_by_frame
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @frame = para "-"
        animate(10) { |frame| @frame.replace(frame.to_s) }
      end
    APP
      seen = 5.times.map do
        advance(0.1)
        layout_tree.find { |node| node[:kind] == "Para" }[:text]
      end
      assert_equal %w[0 1 2 3 4], seen
    TEST
    assert_spec_passed(run)
  end

  def test_animate_runs_on_the_real_clock_too
    run = run_real(<<~APP, argv: ->(app) { ["peek", app, "--wait", "0.3", "--layout", "--wait", "0.3", "--layout"] })
      Shoes.app do
        @frame = para "-"
        animate(20) { |frame| @frame.replace("frame \#{frame}") }
      end
    APP
    assert_clean_exit(run)
    # Frames move on during each wait. How many is the machine's speed, not ours: a late timer
    # skips the frames it missed, and a 3-core macOS runner fired 3 where 6 were due.
    first, second = run.stdout.scan(/"frame (\d+)"/).flatten.map(&:to_i)
    assert_operator first, :>=, 1, run.stdout
    assert_operator second, :>, first, run.stdout
  end

  def test_keys_reach_the_app_keypress_block_unless_a_field_has_focus
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        $keys = []
        @field = edit_line
        keypress { |key| $keys << key }
      end
    APP
      press_key("a")
      press_key("left")
      press_key("control_q")
      assert_equal ["a", :left, :control_q], $keys

      click_on(edit_line)
      type_text("xy")
      press_key("escape")
      assert_equal ["a", :left, :control_q, :escape], $keys, "typing into the field is not a keypress"
      assert_equal "xy", edit_line.text
    TEST
    assert_spec_passed(run)
  end

  def test_dialogs_answer_from_stubs_and_never_open
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @said = para ""
        button("ask") { @said.replace(ask("Your name?").to_s) }
        button("confirm") { @said.replace(confirm("Sure?").inspect) }
      end
    APP
      stub_dialog(:ask, "Nick")
      click_on("ask")
      assert_equal "Nick", para.text
      click_on("ask")
      assert_equal "", para.text, "an unstubbed ask answers quietly"
      click_on("confirm")
      assert_equal "false", para.text
      assert_equal [["ask", "Your name?"], ["ask", "Your name?"], ["confirm", "Sure?"]], dialogs_seen
    TEST
    assert_spec_passed(run)
  end

  def test_stacks_pile_children_up_and_flows_line_them_up_and_wrap
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app(width: 300, height: 300) do
        @flow = flow(width: 250) { %w[F0 F1 F2].each { |name| button name, width: 100, height: 30 } }
        @stack = stack(width: 250) { %w[S0 S1 S2].each { |name| button name, width: 100, height: 30 } }
      end
    APP
      rect = ->(name) { layout_of(button(name)).to_a }
      assert_equal [0, 0, 100, 30], rect["F0"]
      assert_equal [100, 0, 100, 30], rect["F1"]
      assert_equal [0, 30, 100, 30], rect["F2"], "no room for a third: the flow wraps"
      assert_equal [0, 0, 250, 60], layout_of(flow("@flow")).to_a

      assert_equal [0, 60, 100, 30], rect["S0"], "no room beside the flow: the stack starts a new row"
      assert_equal [0, 90, 100, 30], rect["S1"]
      assert_equal [0, 120, 100, 30], rect["S2"]
      assert_equal [0, 60, 250, 90], layout_of(stack("@stack")).to_a
    TEST
    assert_spec_passed(run)
  end

  def test_children_land_where_lacci_put_them
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @s = stack { @b = para "b"; para "d" }
        @s.prepend { para "a1"; para "a2" }
        @s.after(@b) { para "c" }
        @s.before(@b) { para "a3" }
      end
    APP
      texts = layout_tree.select { |node| node[:kind] == "Para" }.map { |node| node[:text] }
      assert_equal %w[a1 a2 a3 b c d], texts
      tops = layout_tree.select { |node| node[:kind] == "Para" }.map { |node| node[:y] }
      assert_equal tops.sort, tops, "and top to bottom in that order"
    TEST
    assert_spec_passed(run)
  end

  def test_hover_and_leave_follow_the_pointer
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        $seen = []
        @b = button("B")
        @b.hover { $seen << :hover }
        @b.leave { $seen << :leave }
      end
    APP
      button.trigger_hover
      assert_equal [:hover], $seen
      button.trigger_leave
      assert_equal [:hover, :leave], $seen
    TEST
    assert_spec_passed(run)
  end

  def test_slot_click_motion_and_wheel_subscriptions
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app(width: 400, height: 300) do
        $events = []
        flow(height: 100) do
          button("inside") { $events << :button }
          click { |button, x, y| $events << [:click, button, x, y] }
        end
        motion { |x, y, mods| $events << [:motion, x, y, mods] }
        wheel { |delta, x, y| $events << [:wheel, delta, x, y] }
      end
    APP
      click_at(300, 50)
      assert_includes $events, [:click, 1, 300, 50], "a press in the flow's box, away from the button"
      assert_includes $events, [:motion, 300, 50, ""]

      $events.clear
      click_on("inside")
      assert_includes $events, :button
      refute $events.any? { |event| event.is_a?(Array) && event.first == :click }, "the button took the press"

      $events.clear
      wheel(30, x: 10, y: 20)
      assert_includes $events, [:wheel, -30, 10, 20], "wheel delta is positive for up, so scrolling down is negative"
    TEST
    assert_spec_passed(run)
  end

  def test_a_scrolling_stack_scrolls_on_the_wheel_and_from_ruby
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app(width: 200, height: 200) do
        @list = stack(height: 100, scroll: true) { 20.times { |i| para "line \#{i}" } }
      end
    APP
      first = -> { layout_tree.find { |node| node[:text] == "line 0" }[:y] }
      top = first.call
      assert_equal 4, top, "the first line sits in its 4 px text margin"
      wheel(50, x: 20, y: 50)
      assert_equal 50, stack("@list").scroll_top, "Rust reports where it scrolled to"
      assert_equal top - 50, first.call

      stack("@list").scroll_top = 10
      wait_frames
      assert_equal top - 10, first.call
    TEST
    assert_spec_passed(run)
  end

  # Real windows (ghosts through run_real: they present frames, but nobody can see or click
  # them), so these run only when asked: SCARPE_NATIVE_WINDOWED_TESTS=1 bundle exec rake native_test

  def test_a_window_paints_real_frames
    skip_unless_windowed_tests
    run = run_real(<<~APP, headless: false, env: { "SCARPE_NATIVE_INACTIVE" => "1" }, test_code: <<~TEST)
      Shoes.app { @p = para "In a window" }
    APP
      assert_operator wait_frames(2), :>=, 2, "frames presented to the screen"
      assert_equal [255, 255, 255, 255], pixel_at(300, 300)
    TEST
    assert_spec_passed(run)
  end

  def test_exit_after_closes_the_window_and_the_app_quits_cleanly
    skip_unless_windowed_tests
    run = run_real(<<~APP, headless: false, env: { "SCARPE_NATIVE_ARGS" => "--fonts bundled --exit-after 1" })
      Shoes.app { para "Closing by itself" }
    APP
    assert_clean_exit(run)
    assert_empty run.stderr.lines.grep(/ChildDied|exited with status/)
  end

  def test_peek_clicks_and_prints_the_layout
    run = run_real(<<~APP, argv: ->(app) { ["peek", app, "--click", "Go", "--layout"] })
      Shoes.app do
        @p = para "Waiting"
        button("Go") { @p.replace("Gone") }
      end
    APP
    assert_clean_exit(run)
    assert_match(/\Aclick "Go" -> #\d+ at /, run.stdout)
    assert_match(/^#\d+ Para [\d.]+,[\d.]+ [\d.]+x[\d.]+ "Gone"$/, run.stdout)
  end

  # Hackety Hack's turtle put "execute" and "draw all" at the right of their rows, so both rows
  # of step-mode controls fit the window it opens (Turtle Stars and Turtle Barbwire use them).
  def test_the_step_mode_turtle_fits_its_controls_in_its_window
    run = run_real(<<~APP, test_code: <<~TEST)
      require "scarpe/turtle"
      Turtle.start { forward 10 }
    APP
      window = Shoes.APPS.first
      lowest = buttons.map { |b| layout_of(b) }.map { |r| r.y + r.h }.max
      assert_operator lowest, :<=, window.height, "every button is inside the window"
      execute = layout_of(find_button("execute"))
      assert_in_delta window.width - execute.w, execute.x, 1, "execute sits at the right of the next-command row"
    TEST
    assert_spec_passed(run)
  end

  private

  def skip_unless_windowed_tests
    skip "set SCARPE_NATIVE_WINDOWED_TESTS=1 to open real windows" unless ENV["SCARPE_NATIVE_WINDOWED_TESTS"]
  end
end
