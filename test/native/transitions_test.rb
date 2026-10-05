# frozen_string_literal: true

require_relative "helper"

class TransitionsTest < Minitest::Test
  include NativeTestHelpers

  def setup
    skip_without_real_binary
  end

  def assert_spec_passed(run)
    super
    # Damage checking falls back to a full paint on mismatch; pixels alone can
    # pass while the window's incremental repaint path is wrong.
    refute_includes run.stderr, "[scarpe-native] damage check:"
  end

  APP = <<~RUBY
    Shoes.app(width: 240, height: 160) do
      @panel = stack(left: 10, top: 10, width: 100, height: 60) { background red }
      @bar = progress width: 100, top: 90
    end
  RUBY

  def test_frozen_clock_samples_defaults_and_synchronizes_getters_at_completion
    run = run_real(APP, env: { "SCARPE_NATIVE_DAMAGE" => "check" }, test_code: <<~TEST)
      panel = Shoes.APPS.first.instance_variable_get(:@panel)
      bar = Shoes.APPS.first.instance_variable_get(:@bar)
      ended = []
      fade = panel.transition(duration: 1, opacity: 0, displace_left: 80) { ended << :panel }
      fill = bar.transition(duration: 1, fraction: 0.8) { ended << :bar }
      assert_instance_of Shoes::Transition, fade
      advance 0.5
      assert fade.active?
      assert fill.active?
      assert_empty ended
      assert_equal [255, 223, 223, 255], pixel_at(90, 20)
      assert_equal 80, layout_of(stack("@panel")).x
      advance 0.5
      refute fade.active?
      refute fill.active?
      assert_equal [:panel, :bar], ended
      assert_equal 0, panel.opacity
      assert_equal 80, panel.displace_left
      assert_equal 0.8, bar.fraction
      wait_frames
      assert_equal [:panel, :bar], ended
    TEST
    assert_spec_passed(run)
  end

  def test_replacement_cancel_and_style_updates_keep_sampled_values
    run = run_real(APP, test_code: <<~TEST)
      panel = Shoes.APPS.first.instance_variable_get(:@panel)
      ended = []
      old = panel.transition(duration: 1, opacity: 0, displace_left: 80) { ended << :old }
      independent = panel.transition(duration: 1, displace_top: 40) { ended << :independent }
      advance 0.5
      reverse = panel.transition(duration: 1, opacity: 1) { ended << :reverse }
      refute old.active?
      assert independent.active?
      assert_in_delta 0.125, panel.opacity
      assert_equal 70, panel.displace_left
      advance 0.5
      assert_equal [:independent], ended
      assert_same reverse, reverse.cancel
      reverse.cancel
      refute reverse.active?
      assert_in_delta 0.890625, panel.opacity
      assert_equal 40, panel.displace_top
      group = panel.transition(duration: 1, opacity: 0, displace_left: 90) { ended << :group }
      advance 0.5
      panel.opacity = 0.6
      refute group.active?
      assert_equal 0.6, panel.opacity
      assert_in_delta 87.5, panel.displace_left
      advance 2
      assert_equal 0.6, panel.opacity
      assert_equal [:independent], ended
    TEST
    assert_spec_passed(run)
  end

  def test_zero_duration_completes_after_a_frame_and_callbacks_can_start_successors
    run = run_real(APP, test_code: <<~TEST)
      panel = Shoes.APPS.first.instance_variable_get(:@panel)
      ended = []
      first = panel.transition(duration: 0, opacity: 0) do
        refute first.active?
        assert_equal 0, panel.opacity
        ended << :first
        panel.transition(duration: 0, opacity: 1) { ended << :second }
      end
      assert first.active?
      assert_empty ended
      wait_frames
      assert_equal [:first], ended
      wait_frames
      assert_equal [:first, :second], ended
      assert_equal 1, panel.opacity
    TEST
    assert_spec_passed(run)
  end

  def test_cancellation_suppresses_a_completion_already_in_the_inbox
    run = run_real(APP, test_code: <<~TEST)
      panel = Shoes.APPS.first.instance_variable_get(:@panel)
      called = false
      motion = panel.transition(duration: 0, opacity: 0) { called = true }
      service = Shoes::DisplayService.display_service
      service.child.request(:frames, n: 1)
      assert motion.active?
      motion.cancel
      refute motion.active?
      assert_equal 0, panel.opacity
      wait_frames
      refute called
    TEST
    assert_spec_passed(run)
  end

  def test_removal_and_closing_settle_handles_without_calling_completion
    run = run_real(APP + <<~APP2, test_code: <<~TEST)
      Shoes.app(width: 100, height: 80) { @other = stack { para "Other" } }
    APP2
      first, second = Shoes.APPS
      panel = first.instance_variable_get(:@panel)
      other = second.instance_variable_get(:@other)
      ended = []
      one = panel.transition(duration: 0, opacity: 0) { ended << :one }
      two = other.transition(duration: 0, opacity: 0) { ended << :two }
      panel.remove
      second.close
      refute one.active?
      refute two.active?
      wait_frames
      assert_empty ended
    TEST
    assert_spec_passed(run)
  end

  def test_invalid_arguments_do_not_cancel_an_existing_transition
    run = run_real(APP, test_code: <<~TEST)
      app = Shoes.APPS.first
      panel = app.instance_variable_get(:@panel)
      active = panel.transition(duration: 1, opacity: 0)
      [Float::NAN, Float::INFINITY, -1, "1", nil].each do |duration|
        assert_raises(ArgumentError) { panel.transition(duration: duration, opacity: 1) }
      end
      [{}, {opacity: 2}, {opacity: Float::NAN}, {opacity: "0.5"}, {width: 10}, {fraction: 0.5}, {displace_left: 1e100}].each do |props|
        assert_raises(ArgumentError) { panel.transition(**props) }
      end
      assert_raises(ArgumentError) { app.transition(opacity: 0) }
      assert active.active?
      advance 1
      refute active.active?
      assert_equal 0, panel.opacity
      panel.remove
      assert_raises(ArgumentError) { panel.transition(opacity: 1) }
    TEST
    assert_spec_passed(run)
  end

  def test_last_window_close_suppresses_completions_already_waiting_in_ruby
    run = run_real(APP, test_code: <<~TEST)
      app = Shoes.APPS.first
      panel = app.instance_variable_get(:@panel)
      called = false
      motion = panel.transition(duration: 0, opacity: 0) { called = true }
      service = Shoes::DisplayService.display_service
      service.child.request(:frames, n: 1)
      app.close
      refute motion.active?
      service.pump.drain
      refute called
    TEST
    assert_spec_passed(run)
  end

  def test_callback_errors_leave_the_handle_settled
    run = run_real(APP, test_code: <<~TEST)
      panel = Shoes.APPS.first.instance_variable_get(:@panel)
      motion = panel.transition(duration: 0, opacity: 0) { raise "completion failed" }
      error = assert_raises(RuntimeError) { wait_frames }
      assert_equal "completion failed", error.message
      refute motion.active?
      motion.cancel
      wait_frames
      assert_equal 0, panel.opacity
    TEST
    assert_spec_passed(run)
  end

  def test_native_frames_continue_while_a_ruby_handler_is_busy
    run = run_real(<<~APP)
      Shoes.app(width: 100, height: 80) do
        panel = stack(width: 40, height: 40) { background red }
        timer(0.01) do
          called = false
          motion = panel.transition(duration: 0.03, opacity: 0) { called = true }
          sleep 0.4
          motion.cancel
          raise "native transition stalled with Ruby" unless panel.opacity == 0
          raise "cancelled callback ran" if called
          puts "transition finished during Ruby handler"
          close
        end
      end
    APP
    assert_clean_exit(run)
    assert_includes run.stdout, "transition finished during Ruby handler"
  end
end
