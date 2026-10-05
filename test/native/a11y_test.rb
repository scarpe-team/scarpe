# frozen_string_literal: true

require_relative "helper"

# Screen readers (native/DESIGN.md 12, ledger N1): real Lacci apps through the real Rust child,
# read back the way a screen reader meets them and worked the way a screen reader works them.
# Each test proves Lacci sends what the accessibility tree is built from (labels, checked, text,
# items, chosen, fraction, alt) and that an action runs the app's own Ruby handler.
class A11yTest < Minitest::Test
  include NativeTestHelpers

  def setup
    skip_without_real_binary
  end

  def test_a_screen_reader_meets_the_controls_lacci_made
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app(title: "Order") do
        para "Name"
        @name = edit_line "Nick"
        flow do
          @keep = check checked: true
          para "Remember me"
        end
        @drink = list_box items: ["Tea", "Coffee"], choose: "Tea"
        @go = button "Order", tooltip: "Sends it"
        @bar = progress fraction: 0.5
        @pin = edit_line "1234", secret: true
        image #{File.join(ROOT, "spec/support/assets/red-40x30.png").inspect}, alt: "A red square"
        para "Read ", link("the menu") { }, " first."
      end
    APP
      tree = a11y_tree
      assert_equal ["window", "Order"], [tree[:role], tree[:name]]
      nodes = a11y_nodes
      find = ->(role) { nodes.find { |node| node[:role] == role } }

      assert_equal ["Name", "Nick"], find.call("text_input").values_at(:name, :value), "named by the text before it"
      assert_equal ["Remember me", true], find.call("check_box").values_at(:name, :toggled), "and a check by the text after"
      assert_equal "Tea", find.call("combo_box")[:value]
      assert_equal %w[Tea Coffee], find.call("combo_box")[:children].map { |option| option[:name] }
      assert_equal ["Order", "Sends it", %w[click focus]], find.call("button").values_at(:name, :description, :actions)
      assert_equal 0.5, find.call("progress_indicator")[:numeric][:value]
      assert_equal "\\u2022" * 4, find.call("password_input")[:value], "a secret reads as bullets"
      assert_equal "A red square", find.call("image")[:name]
      link = find.call("link")
      assert_equal "the menu", link[:name]
      assert_equal layout_of(button("@go")).to_a, find.call("button")[:bounds], "where the layout put it"
    TEST
    assert_spec_passed(run)
  end

  def test_a_screen_reader_works_the_app_through_its_own_handlers
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @said = para "nothing"
        @go = button("Go") { @said.replace "pressed" }
        @keep = check
        @name = edit_line { |line| @said.replace "typed \#{line.text}" }
        @drink = list_box(items: ["Tea", "Coffee"]) { |box| @said.replace "chose \#{box.text}" }
        para link("Away") { @said.replace "followed" }
      end
    APP
      said = -> { para("@said").text }

      a11y_action button("@go"), :click
      assert_equal "pressed", said.call

      refute check("@keep").checked?
      a11y_action check("@keep"), :click
      assert check("@keep").checked?, "Lacci toggles the check"
      assert_equal true, a11y_nodes.find { |node| node[:role] == "check_box" }[:toggled], "and the tree follows its echo"

      a11y_action edit_line("@name"), :set_value, "Noah"
      assert_equal "typed Noah", said.call
      assert_equal "Noah", edit_line("@name").text

      a11y_action list_box("@drink"), :set_value, "Coffee"
      assert_equal "chose Coffee", said.call

      a11y_action a11y_nodes.find { |node| node[:role] == "link" }, :click
      assert_equal "followed", said.call

      a11y_action edit_line("@name"), :focus
      assert_equal edit_line("@name").linkable_id, focused_drawable.linkable_id
    TEST
    assert_spec_passed(run)
  end

  def test_custom_dialog_metadata_follows_ruby_updates_and_keeps_controls_working
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @panel = stack(width: 300, height: 180, accessibility_role: :dialog,
          accessibility_label: "تصدير الكتاب", accessibility_modal: true) do
          para "Name"
          @name = edit_line "Book"
          @save = button("Save") { @status.text = "saved" }
        end
        @status = para "ready"
      end
    APP
      panel = stack("@panel")
      node = -> { a11y_nodes.find { |n| n[:id] == panel.linkable_id } }
      assert_equal ["dialog", "تصدير الكتاب", true], node.call.values_at(:role, :name, :modal)
      assert_equal layout_of(panel).to_a, node.call[:bounds]
      assert_equal %w[label text_input button], node.call[:children].map { |n| n[:role] }
      a11y_action edit_line("@name"), :focus
      a11y_action edit_line("@name"), :set_value, "New title"
      assert_equal "New title", edit_line("@name").text
      a11y_action button("@save"), :click
      assert_equal "saved", para("@status").text

      panel.accessibility_label = "Export options"
      panel.style(accessibility_modal: false)
      wait_frames
      assert_equal "Export options", node.call[:name]
      refute node.call.key?(:modal)
      assert_equal edit_line("@name").linkable_id, focused_drawable.linkable_id
      panel.style(accessibility_role: nil, accessibility_label: nil, accessibility_modal: nil)
      wait_frames
      assert_nil node.call, "clearing the role makes the slot transparent again"
      assert_equal edit_line("@name").linkable_id, focused_drawable.linkable_id
      panel.accessibility_role = "dialog"
      panel.style(accessibility_label: "Export again", accessibility_modal: true)
      wait_frames
      assert_equal ["dialog", "Export again", true], node.call.values_at(:role, :name, :modal)
      assert_equal "New title", edit_line("@name").text
    TEST
    assert_spec_passed(run)
  end

  def test_nested_custom_dialogs_follow_visibility_changes
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        @outer = flow(accessibility_role: "dialog", accessibility_label: "Export") do
          @cancel = button "Cancel"
          @inner = stack(accessibility_role: :dialog, accessibility_label: "Confirm", accessibility_modal: true) do
            button "Replace"
          end
        end
      end
    APP
      dialogs = -> { a11y_nodes.select { |n| n[:role] == "dialog" } }
      assert_equal ["Export", "Confirm"], dialogs.call.map { |n| n[:name] }
      refute dialogs.call.first.key?(:modal)
      assert_equal true, dialogs.call.last[:modal]
      assert_equal "dialog", dialogs.call.first[:children].last[:role]
      a11y_action button("@cancel"), :focus
      stack("@inner").hide
      wait_frames
      assert_equal ["Export"], dialogs.call.map { |n| n[:name] }
      stack("@inner").show
      wait_frames
      assert_equal ["Export", "Confirm"], dialogs.call.map { |n| n[:name] }
      assert_equal button("@cancel").linkable_id, focused_drawable.linkable_id
      flow("@outer").hide
      wait_frames
      assert_empty dialogs.call
    TEST
    assert_spec_passed(run)
  end

  def test_peek_prints_what_a_screen_reader_meets
    run = run_real(<<~APP, argv: ->(app) { ["peek", app, "--a11y"] })
      Shoes.app(title: "Order") do
        flow do
          check checked: true
          para "Remember me"
        end
        para "Name"
        edit_line "Nick"
        button "Order"
      end
    APP
    assert_clean_exit(run)
    lines = run.stdout.lines.map(&:rstrip)
    assert_equal '#1 window "Order" (focused)', lines.first
    assert_includes lines, '  #4 check_box "Remember me" (checked)', "one line a node, indented under the window"
    assert_includes lines, '  #7 text_input "Name" = "Nick"', "the name, then the value"
    assert_includes lines, '  #8 button "Order"'
    refute File.exist?(File.join(run.dir, "peek.png")), "--a11y is an output of its own, so no picture"
  end

  # A real window (a ghost: nobody can see or click it) opens with its screen reader adapter in
  # place, and the tree reads the same there. Runs only with SCARPE_NATIVE_WINDOWED_TESTS=1.
  def test_a_window_carries_the_same_tree
    skip_unless_windowed_tests
    run = run_real(<<~APP, headless: false, test_code: <<~TEST)
      Shoes.app { @go = button "Go" }
    APP
      assert_operator wait_frames(2), :>=, 2, "the window presents frames"
      button_node = a11y_nodes.find { |node| node[:role] == "button" }
      assert_equal "Go", button_node[:name]
    TEST
    assert_spec_passed(run)
  end

  # VoiceOver's side of a real window (a ghost): AppKit hands out our nodes with their roles and
  # titles, and a press and a new value made through AppKit come back through AccessKit to the
  # app's own handlers. macOS only; runs with SCARPE_NATIVE_WINDOWED_TESTS=1.
  def test_voiceover_reads_and_works_a_real_window
    skip_unless_windowed_tests
    skip "the platform tree is read through AppKit" unless RUBY_PLATFORM.include?("darwin")
    run = run_real(<<~APP, headless: false, test_code: <<~TEST)
      Shoes.app do
        @said = para "nothing"
        @go = button("Go") { @said.replace "pressed" }
        flow do
          @keep = check
          para "Keep"
        end
        para "Name"
        @name = edit_line { |line| @said.replace "typed \#{line.text}" }
      end
    APP
      wait_frames(2)
      nodes = a11y_nodes(platform: true)
      seen = nodes.map { |node| node.values_at(:role, :title) }
      assert_includes seen, ["AXButton", "Go"]
      assert_includes seen, ["AXCheckBox", "Keep"], "named by the text after it, as AppKit reports"
      assert_includes seen, ["AXTextField", "Name"]
      assert_includes nodes.map { |node| node[:value] }, "nothing", "static text reads its words"

      a11y_action "Go", :click, nil, platform: true
      wait_frames
      assert_equal "pressed", para("@said").text, "a VoiceOver press runs the button's block"

      a11y_action "Keep", :click, nil, platform: true
      wait_frames
      assert check("@keep").checked?

      a11y_action "Name", :set_value, "Noah", platform: true
      wait_frames
      assert_equal "typed Noah", para("@said").text
    TEST
    assert_spec_passed(run)
  end

  private

  def skip_unless_windowed_tests
    skip "set SCARPE_NATIVE_WINDOWED_TESTS=1 to open real (ghost) windows" unless ENV["SCARPE_NATIVE_WINDOWED_TESTS"]
  end
end
