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

  def test_switches_reuse_check_callbacks_keyboard_and_disabled_behavior
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app(width: 240, height: 120) do
        @calls = 0
        @said = para "0", left: 80, top: 20
        @toggle = check(left: 20, top: 20, variant: :switch, tooltip: "Show diacritics",
          color: rgb(174, 71, 33), background_color: "#4a4543") do |control|
          @calls += 1
          @said.replace "\#{@calls}:\#{control.checked?}"
        end
        @next = button "Next", left: 20, top: 70
      end
    APP
      toggle = check("@toggle")
      node = -> { a11y_nodes.find { |n| n[:id] == toggle.linkable_id } }
      said = -> { para("@said").text }
      assert_equal [40, 28], layout_of(toggle).to_a.last(2)
      assert_equal ["switch", "Show diacritics", false], node.call.values_at(:role, :name, :toggled)
      assert_equal [255, 255, 255], pixel_at(32, 34).first(3)
      assert_equal [74, 69, 67], pixel_at(48, 34).first(3)
      toggle.trigger_click
      assert toggle.checked?
      assert_equal "1:true", said.call, "the handler sees the new checked state exactly once"
      assert_equal [174, 71, 33], pixel_at(32, 34).first(3)
      toggle.obj.focus
      wait_frames
      press_key("space")
      refute toggle.checked?
      assert_equal "2:false", said.call
      press_key("enter")
      assert_equal "3:true", said.call
      a11y_action toggle, :click
      assert_equal "4:false", said.call
      assert_equal false, node.call[:toggled]

      toggle.obj.checked = true
      toggle.obj.direction = :rtl
      wait_frames
      assert_equal "4:false", said.call, "programmatic updates do not invoke the click handler"
      assert_equal true, node.call[:toggled]
      assert_equal [255, 255, 255], pixel_at(32, 34).first(3)
      assert_equal [174, 71, 33], pixel_at(48, 34).first(3)
      toggle.obj.color = "red"
      wait_frames
      assert_equal [255, 0, 0], pixel_at(48, 34).first(3)
      toggle.obj.variant = nil
      wait_frames
      assert_equal "check_box", node.call[:role]
      assert_equal [18, 18], layout_of(toggle).to_a.last(2)
      assert toggle.checked?
      toggle.obj.variant = :switch
      toggle.obj.state = "disabled"
      wait_frames
      assert_equal "switch", node.call[:role]
      assert_equal [40, 28], layout_of(toggle).to_a.last(2)
      assert_equal true, node.call[:disabled]
      assert_nil node.call[:actions]
      toggle.trigger_click
      press_key("space")
      assert_equal "4:false", said.call, "disabled switches ignore the pointer and keys"
      press_key("tab")
      assert_equal button("@next").linkable_id, focused_drawable.linkable_id
      toggle.obj.state = nil
      wait_frames
      a11y_action toggle, :click
      assert_equal "5:false", said.call
    TEST
    assert_spec_passed(run)
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
