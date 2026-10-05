# frozen_string_literal: true

require_relative "helper"

class NativeScrollCallbacksTest < Minitest::Test
  include NativeTestHelpers

  def test_scroll_messages_notify_changes_without_echoing_commands
    reports = [0, 40, 40, 0].map { |top| { "t" => "scroll", "id" => { "kind" => "Stack" }, "top" => top } }
    run = run_app(<<~APP, script: [{ "on" => "run", "emit" => reports }], test_code: <<~TEST)
      $seen = []
      Shoes.app do
        @list = stack(height: 100, scroll: true)
        @list.on_scroll { |top| $seen << [top, @list.scroll_top, self] }
      end
    APP
      app = Shoes.APPS.first
      assert_equal [[40, 40, app], [0, 0, app]], $seen
      assert_equal 0, stack("@list").scroll_top
    TEST
    assert_spec_passed(run)
    assert_empty run.of_type("scroll_to"), "reports must not echo scroll commands"
    refute run.of_type("props").any? { |message| message["props"].key?("scroll_top") }
  end

  def test_late_messages_for_removed_slots_and_closed_windows_are_ignored
    run = run_app(<<~APP, test_code: <<~TEST)
      $seen = []
      Shoes.app do
        $parent = stack do
          $removed = stack
          $removed.on_scroll { |top| $seen << [:removed, top] }
        end
        $closing = window do
          $closed = stack
          $closed.on_scroll { |top| $seen << [:closed, top] }
        end
        $live = stack
        $live.on_scroll { |top| $seen << [:live, top] }
      end
    APP
      service = Scarpe::Native::DisplayService.instance
      report = ->(slot, top) { service.receive("t" => "scroll", "id" => slot.linkable_id, "top" => top) }
      $parent.clear
      $closing.close
      report.call($removed, 10)
      report.call($closed, 20)
      service.receive("t" => "scroll", "id" => -999, "top" => 30)
      assert_empty $seen
      assert_equal 0, $removed.scroll_top
      assert_equal 0, $closed.scroll_top
      report.call($live, 40)
      assert_equal [[:live, 40]], $seen, "another window's slots still receive reports"
    TEST
    assert_spec_passed(run)
  end

  def test_a_scroll_handler_can_remove_its_slot_while_reports_are_queued
    reports = [10, 20].map { |top| { "t" => "scroll", "id" => { "kind" => "Stack" }, "top" => top } }
    run = run_app(<<~APP, script: [{ "on" => "run", "emit" => reports }], test_code: <<~TEST)
      $seen = []
      Shoes.app do
        $list = stack
        $list.on_scroll do |top|
          $seen << [top, $list.scroll_top]
          $list.remove
        end
      end
    APP
      assert $list.destroyed
      assert_equal [[10, 10]], $seen
      assert_equal 10, $list.scroll_top
    TEST
    assert_spec_passed(run)
  end

  def test_handler_errors_reach_shoes_on_error_and_later_reports_still_run
    run = run_app(<<~APP, test_code: <<~TEST)
      $errors = []
      $seen = []
      Shoes.on_error { |error| $errors << error.slice("class", "message", "during") }
      Shoes.app do
        $list = stack
        $list.on_scroll do |top|
          $seen << [top, $list.scroll_top]
          raise ArgumentError, "scroll failed" if top == 40
        end
      end
    APP
      service = Scarpe::Native::DisplayService.instance
      [40, 40, 80].each { |top| service.receive("t" => "scroll", "id" => $list.linkable_id, "top" => top) }
      assert_equal [[40, 40], [80, 80]], $seen, "failed notifications still update and deduplicate the offset"
      assert_equal [{ "class" => "ArgumentError", "message" => "scroll failed", "during" => "handler" }], $errors
      assert_equal 80, $list.scroll_top
    TEST
    assert_spec_passed(run)
    assert_includes run.stderr, "scroll handler for"
    assert_includes run.stderr, "ArgumentError: scroll failed"
  end

  def test_wheel_callbacks_observe_clamped_offsets_and_can_update_the_ui
    skip_without_real_binary
    run = run_real(<<~APP, test_code: <<~TEST)
      $seen = []
      Shoes.app(width: 300, height: 200) do
        @list = stack(width: 100, height: 100, scroll: true) { stack(height: 500) }
        @status = para "ready"
        @list.on_scroll do |top|
          $seen << [top, @list.scroll_top]
          @status.text = "offset: \#{top}"
        end
      end
    APP
      wheel(60, x: 20, y: 50)
      assert_equal [[60, 60]], $seen
      assert_equal "offset: 60", para("@status").text
      wheel(1000, x: 20, y: 50)
      wheel(10, x: 20, y: 50)
      wheel(-1000, x: 20, y: 50)
      assert_equal [[60, 60], [400, 400], [0, 0]], $seen

      stack("@list").scroll_top = 25
      wait_frames
      assert_equal 3, $seen.size, "Ruby assignments do not notify"
      wheel(5, x: 20, y: 50)
      assert_equal [30, 30], $seen.last
    TEST
    assert_spec_passed(run)
  end

  def test_nested_flow_and_stack_notifications_do_not_bubble
    skip_without_real_binary
    run = run_real(<<~APP, test_code: <<~TEST)
      $seen = []
      Shoes.app(width: 300, height: 200) do
        @outer = stack(left: 20, top: 20, width: 120, height: 100, scroll: true) do
          @inner = flow(width: 100, height: 60, scroll: true) { stack(height: 300) }
          stack(height: 400)
        end
        @outer.on_scroll { |top| $seen << [:outer, top, @outer.scroll_top] }
        @inner.on_scroll { |top| $seen << [:inner, top, @inner.scroll_top] }
      end
    APP
      wheel(50, x: 50, y: 40)
      assert_equal [[:inner, 50, 50]], $seen
      assert_equal 0, stack("@outer").scroll_top
      wheel(20, x: 135, y: 100)
      assert_equal [[:inner, 50, 50], [:outer, 20, 20]], $seen
      assert_equal 50, flow("@inner").scroll_top
    TEST
    assert_spec_passed(run)
  end

  def test_window_root_callbacks_surface_errors_to_automation_and_recover
    skip_without_real_binary
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app(width: 200, height: 100) do
        stack(height: 500)
        document_root.on_scroll { raise ArgumentError, "root scroll failed" }
      end
    APP
      root = Shoes.APPS.first.document_root
      error = assert_raises(ArgumentError) { wheel(50, x: 20, y: 50) }
      assert_equal "root scroll failed", error.message
      assert_equal 50, root.scroll_top
      seen = []
      root.on_scroll { |top| seen << [top, root.scroll_top] }
      wheel(10, x: 20, y: 50)
      assert_equal [[60, 60]], seen
    TEST
    assert_spec_passed(run)
  end
end
