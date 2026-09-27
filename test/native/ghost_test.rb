# frozen_string_literal: true

require_relative "helper"

# Ghost windows (native/DESIGN.md 12): SCARPE_NATIVE_GHOST=1 opens real windows that present real
# frames but that nobody can see or click, for automated windowed runs. The first tests check the
# plumbing with the fake child. The rest open real ghosts and ask the window server, never the
# screen, what it shows; they run only with SCARPE_NATIVE_WINDOWED_TESTS=1, on macOS.
class GhostTest < Minitest::Test
  include NativeTestHelpers

  # The alpha of every window a process owns, as the window server has it (JXA, CoreGraphics;
  # reading the window list needs no permission).
  WINDOW_ALPHAS = <<~JS
    ObjC.import('CoreGraphics');
    function run(argv) {
      const pid = parseInt(argv[0], 10);
      const list = ObjC.castRefToObject($.CGWindowListCopyWindowInfo($.kCGWindowListOptionAll, $.kCGNullWindowID));
      return JSON.stringify((ObjC.deepUnwrap(list) || []).filter(w => w.kCGWindowOwnerPID === pid).map(w => w.kCGWindowAlpha));
    }
  JS

  # Shoes-Spec helpers for the windowed tests, run inside the app's process.
  PROBES = <<~'RUBY'
    child = Scarpe::Native::DisplayService.instance.child
    window_alphas = -> { JSON.parse(`/usr/bin/osascript -l JavaScript window_alphas.js #{child.pid}`) }
    front_pid = -> { `/usr/bin/lsappinfo info -only pid "$(/usr/bin/lsappinfo front)"`[/"pid"=(\d+)/, 1].to_i }
  RUBY

  def test_scarpe_native_ghost_passes_the_flag_and_nobody_is_asked_anything
    run = run_app(<<~APP, headless: false, env: { "SCARPE_NATIVE_GHOST" => "1" })
      Shoes.app do
        puts "ask: \#{ask("Your name?").inspect}"
        puts "confirm: \#{confirm("Sure?").inspect}"
        alert("Boo")
        timer(0.05) { Shoes.quit }
      end
    APP
    assert_clean_exit(run)
    assert_includes run.child_argv, "--ghost"
    refute_includes run.child_argv, "--headless"
    assert_equal ['ask: ""', "confirm: false"], run.stdout.lines.map(&:chomp)
    assert_empty run.of_type("req").select { |req| req["op"] == "dialog" }, "nobody can answer a ghost's dialog"
  end

  def test_scarpe_native_ghost_0_is_a_window_like_any_other
    run = run_app(<<~APP, headless: false, env: { "SCARPE_NATIVE_GHOST" => "0" })
      Shoes.app { timer(0.05) { Shoes.quit } }
    APP
    assert_clean_exit(run)
    refute_includes run.child_argv, "--ghost"
  end

  def test_a_ghost_window_is_clear_live_and_never_in_front
    skip_unless_ghosts_can_be_checked
    run = run_ghost(<<~APP, <<~TEST)
      Shoes.app { para "Boo" }
    APP
      #{PROBES}
      assert_operator wait_frames(3), :>=, 3, "frames presented"
      alphas = window_alphas.call
      refute_empty alphas, "the window server has our window"
      assert alphas.all?(&:zero?), "every window of ours is clear: \#{alphas.inspect}"
      refute_equal child.pid, front_pid.call, "the app never comes to the front"
      assert_match(/"UIElement"/, `/usr/bin/lsappinfo info -only applicationtype \#{child.pid}`, "no Dock icon")
    TEST
    assert_spec_passed(run)
  end

  # A regression here must fail without showing anything, so the app asks for an opacity of 0.001
  # (0.1%, nothing anyone could see) and the link's `open` is the fake on PATH.
  def test_a_ghost_stays_clear_and_opens_no_links_whatever_the_app_asks
    skip_unless_ghosts_can_be_checked
    run = run_ghost(<<~APP, <<~TEST)
      Shoes.app do
        button("Fade") { app.opacity = 0.001 }
        para link("Away", click: "https://example.com/")
      end
    APP
      #{PROBES}
      click_on("Fade")
      click_on("Away")
      wait_frames(2)
      sleep 0.5 # the window server takes a moment to show what AppKit was told
      assert_equal 0.001, Shoes.APPS.first.opacity
      alphas = window_alphas.call
      assert alphas.all?(&:zero?), "still clear: \#{alphas.inspect}"
    TEST
    assert_spec_passed(run)
    assert_empty run.open_calls, "a ghost opens no browser"
  end

  def test_a_ghost_answers_dialogs_the_way_a_headless_run_does
    skip_unless_ghosts_can_be_checked
    run = run_ghost(<<~APP, <<~'TEST')
      Shoes.app { para "Boo" }
    APP
      child = Scarpe::Native::DisplayService.instance.child
      assert_equal [nil, false], child.request(:dialog, kind: "alert", message: "Boo", default: nil).values_at("value", "cancelled")
      assert_equal [false, true], child.request(:dialog, kind: "confirm", message: "Sure?", default: nil).values_at("value", "cancelled")
      assert_equal [nil, true], child.request(:dialog, kind: "ask_open_file", message: "Which?", default: nil).values_at("value", "cancelled")
    TEST
    assert_spec_passed(run)
  end

  private

  def run_ghost(app_code, test_code)
    run_real(app_code, headless: false, env: { "SCARPE_NATIVE_GHOST" => "1" }, test_code: test_code) do |dir|
      File.write(File.join(dir, "window_alphas.js"), WINDOW_ALPHAS)
    end
  end

  def skip_unless_ghosts_can_be_checked
    skip_without_real_binary
    skip "set SCARPE_NATIVE_WINDOWED_TESTS=1 to open real (ghost) windows" unless ENV["SCARPE_NATIVE_WINDOWED_TESTS"]
    skip "ghost windows are checked through the macOS window server" unless RUBY_PLATFORM.include?("darwin")
  end
end
