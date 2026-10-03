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

  def test_button_variants_and_theme_colors_can_change_at_runtime
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app(width: 240, height: 220) do
        background "#202020"
        @solid = button "Save", variant: :solid, color: "#ae4721", text_color: white, left: 20, top: 20, width: 100, height: 36
        @outline = button "Cancel", variant: "outline", color: "transparent", border_color: "#abcdef", text_color: white, left: 20, top: 80, width: 100, height: 36
        @ghost = button "More", variant: :ghost, text_color: white, left: 20, top: 140, width: 100, height: 36
      end
    APP
      assert_equal [174, 71, 33, 255], pixel_at(40, 26)
      assert_equal [174, 71, 33, 255], pixel_at(40, 47)
      assert_equal [171, 205, 239, 255], pixel_at(40, 80)
      assert_equal [32, 32, 32, 255], pixel_at(40, 86)
      assert_equal [32, 32, 32, 255], pixel_at(40, 146)

      button("@outline").obj.border_color = "#ff0000"
      button("@solid").obj.variant = :ghost
      button("@solid").obj.color = "transparent"
      wait_frames
      assert_equal [255, 0, 0, 255], pixel_at(40, 80)
      assert_equal [32, 32, 32, 255], pixel_at(40, 26)

      button("@ghost").obj.color = "#ae4721"
      wait_frames
      assert_equal [174, 71, 33, 255], pixel_at(40, 146), "selected ghost uses its explicit fill"
      button("@solid").obj.variant = nil
      button("@solid").obj.color = nil
      wait_frames
      refute_equal pixel_at(40, 26), pixel_at(40, 47), "removing the variant restores the gradient"
    TEST
    assert_spec_passed(run)
  end

  def test_button_variants_keep_mouse_keyboard_accessibility_and_disabled_behavior
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app(width: 240, height: 260) do
        @count = 0
        @note = para "0", top: 210
        %i[solid outline ghost].each_with_index do |variant, index|
          button(variant.to_s, variant: variant, left: 20, top: 20 + index * 60, width: 100, height: 36) do
            @count += 1
            @note.replace(@count.to_s)
          end
        end
      end
    APP
      %w[solid outline ghost].each_with_index do |variant, index|
        control = button(variant)
        node = a11y_nodes.find { |n| n[:name] == variant }
        assert_equal "button", node[:role]
        control.trigger_click
        control.obj.focus
        wait_frames
        assert_equal control.linkable_id, focused_drawable.linkable_id
        press_key("enter")
        press_key("space")
        a11y_action control, :click
        assert_equal ((index + 1) * 4).to_s, para("@note").text

        control.obj.state = "disabled"
        wait_frames
        rect = layout_of(control)
        click_at(rect.x + 5, rect.y + 5)
        press_key("enter")
        press_key("space")
        error = assert_raises(Scarpe::Native::AutomationError) { a11y_action control, :click }
        assert_match(/disabled/, error.message)
        assert_equal ((index + 1) * 4).to_s, para("@note").text, "disabled variants cannot activate"
      end
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
