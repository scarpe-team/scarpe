# frozen_string_literal: true

require_relative "helper"

# The art-input lane's Ruby side: automation aimed at a drawable reaches its own window, and
# `scarpe peek` can look at a second window and turn the wheel. Real Lacci, real Rust child.
class ArtInputTest < Minitest::Test
  include NativeTestHelpers

  TWO_WINDOWS = <<~APP
    Shoes.app(title: "First", width: 300, height: 200) do
      para "One"
      button("Another") do
        window(title: "Second", width: 200, height: 150) do
          @p = para "Two"
          button("Press me") { @p.replace("Pressed") }
        end
      end
    end
  APP

  def setup
    skip_without_real_binary unless name.start_with?("test_unit_")
  end

  # Rust loads a button's icon from the path it is given, so it has to be absolute.
  def test_unit_a_button_icon_travels_as_an_absolute_path
    Dir.chdir(Dir.tmpdir) do
      assert_equal File.join(Dir.pwd, "icon-info.png"), Scarpe::Native::Normalize.prop("Button", "icon", "icon-info.png")
    end
    assert_nil Scarpe::Native::Normalize.prop("Button", "icon", nil)
  end

  # spec app.close failed with "is not visible": a click by id always went to the first window.
  def test_a_drawable_in_a_second_window_can_be_found_and_clicked
    run = run_real(TWO_WINDOWS, test_code: <<~TEST)
      button("Another").trigger_click
      press = button("Press me")
      assert_equal 2, Shoes.APPS.size
      refute_nil layout_of(press), "its box comes from its own window's layout"
      press.trigger_click
      assert_equal "Pressed", para("Pressed").text
    TEST
    assert_spec_passed(run)
  end

  def test_peek_steps_can_aim_at_a_second_window
    run = run_real(TWO_WINDOWS, argv: ->(app) { ["peek", app, "--click", "Another", "--window", "2", "--click", "Press me", "--layout"] })
    assert_clean_exit(run)
    assert_match(/^window #\d+ "Second"$/, run.stdout)
    assert_match(/^#\d+ Para [\d.]+,[\d.]+ [\d.]+x[\d.]+ "Pressed"$/, run.stdout)
    refute_match(/"One"/, run.stdout.split(/^window/).last, "the layout after --window is the second window's")
  end

  def test_peek_says_when_there_is_no_such_window
    run = run_real(TWO_WINDOWS, argv: ->(app) { ["peek", app, "--window", "2", "--layout"] })
    refute run.status.success?
    assert_match(/peek: no window 2 \(1 open\)/, run.stderr)
  end

  def test_peek_turns_the_wheel
    run = run_real(<<~APP, argv: ->(app) { ["peek", app, "--wheel", "30,50,40", "--layout"] })
      Shoes.app(width: 200, height: 200) do
        stack(height: 80, scroll: true) { 10.times { |i| para "line \#{i}" } }
      end
    APP
    assert_clean_exit(run)
    assert_match(/^wheel 30 at 50,40$/, run.stdout)
    # The first line sits in its 4 px text margin (ledger C9), so 30 px of wheel leaves it at -26.
    assert_match(/^#\d+ Para 4,-26 [\d.]+x[\d.]+ hidden "line 0"$/, run.stdout)
  end
end
