# frozen_string_literal: true

require_relative "test_helper"

class TestControls < NienteTest
  # Ledger G1: every control hands its block the control (manual 2918-2921,
  # 3086-3090; Shoes 3 s3t_native.c:189-193). EditLine used to hand over the new
  # String; the examples that read the argument (edit_line-character-count.rb,
  # search.rb) call .text on it, so none relied on the String.
  def test_blocks_are_handed_the_control
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $handed = {}
        @go = button("Go") { |b| $handed[:button] = b }
        @line = edit_line { |line| $handed[:edit_line] = line }
        @later = button "Later"
        @later.click { |b| $handed[:later] = b }
      end
    SHOES_APP
      button("@go").trigger_click
      button("@later").trigger_click
      Shoes::DisplayService.dispatch_event("change", edit_line.linkable_id, "typed")

      assert_same button("@go").obj, $handed[:button]
      assert_same button("@later").obj, $handed[:later]
      assert_same edit_line.obj, $handed[:edit_line]
      assert_equal "typed", $handed[:edit_line].text
    SHOES_SPEC
  end

  # Q7 (27 Sep 2026): a programmatic text= firing change is pinned as a Scarpe
  # extension (ledger G5), and it hands over the control like a typed change.
  def test_setting_text_fires_change_with_the_control
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $changes = []
        @line = edit_line { |line| $changes << line.text }
      end
    SHOES_APP
      edit_line.text = "set by code"
      assert_equal ["set by code"], $changes
    SHOES_SPEC
  end

  def test_handler_setters_return_the_control
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @b = button "b"
        @c = check
        @e = edit_line
        @x = edit_box
      end
    SHOES_APP
      [button, check, edit_line, edit_box].each do |control|
        returned = control.obj.public_send(control.obj.is_a?(Shoes::EditLine) || control.obj.is_a?(Shoes::EditBox) ? :change : :click) { }
        assert_same control.obj, returned
      end
    SHOES_SPEC
  end

  # Ledger G3: "if nothing is selected, text is nil" (manual 3234-3237).
  def test_a_list_box_starts_with_nothing_chosen
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @plain = list_box items: ["Grapes", "Pears"]
        @chosen = list_box items: ["Grapes", "Pears"], choose: "Pears"
      end
    SHOES_APP
      assert_nil list_box("@plain").text
      assert_nil list_box("@plain").display.instance_variable_get(:@data)["chosen"]
      assert_equal "Pears", list_box("@chosen").text
    SHOES_SPEC
  end

  # Ledger G9: buttons, checks and radios take focus like the text inputs do.
  def test_buttons_checks_and_radios_take_focus
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $focused = []
        Shoes::DisplayService.subscribe_to_event("focus", :any) do |*_args, event_target: nil, **_kw|
          $focused << event_target
        end
        @b = button "b"
        @c = check
        @r = radio
      end
    SHOES_APP
      [button, check, radio].each do |control|
        assert_same control.obj, control.focus
      end
      assert_equal [button, check, radio].map(&:linkable_id), $focused
    SHOES_SPEC
  end

  # Ledger M5: text "returns a string of characters", and progress a decimal, from
  # the start (Shoes 3 gives "" and 0.0).
  def test_empty_inputs_start_empty_rather_than_nil
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        edit_line
        edit_box
        progress
      end
    SHOES_APP
      assert_equal ["", "", 0.0], [edit_line.text, edit_box.text, progress.fraction]
    SHOES_SPEC
  end
end
