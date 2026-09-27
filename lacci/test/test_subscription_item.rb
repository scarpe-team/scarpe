# frozen_string_literal: true

require_relative "test_helper"

# Each display event must reach the user's block exactly once, with the
# arguments the typed handler builds (DESIGN.md section 10, item 1).
class TestSubscriptionItem < NienteTest
  def test_animate_block_runs_once_per_frame
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @frames = []
        @anim = animate(10) { |frame| @frames << frame }
      end
    SHOES_APP
      app = Shoes.APPS[0]
      anim = app.instance_variable_get(:@anim)
      Shoes::DisplayService.dispatch_event("animate", anim.linkable_id, 0)
      assert_equal [0], app.instance_variable_get(:@frames)
    SHOES_SPEC
  end

  def test_keypress_block_gets_one_symbol
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @keys = []
        keypress { |key| @keys << key }
      end
    SHOES_APP
      app = Shoes.APPS[0]
      kp = subscription_item
      Shoes::DisplayService.dispatch_event("keypress", kp.linkable_id, ":left")
      assert_equal [:left], app.instance_variable_get(:@keys)
    SHOES_SPEC
  end

  def test_slot_click_block_runs_once
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @presses = []
        click { |button, left, top| @presses << [button, left, top] }
      end
    SHOES_APP
      app = Shoes.APPS[0]
      watcher = subscription_item
      Shoes::DisplayService.dispatch_event("click", watcher.linkable_id, 1, 5, 6)
      assert_equal [[1, 5, 6]], app.instance_variable_get(:@presses)
    SHOES_SPEC
  end

  # Manual 1877, 1989, 2111: animate, every and timer return a Shoes::Animation,
  # Shoes::Every and Shoes::Timer. A display still sees each as a SubscriptionItem
  # (wire contract (e)), so it needs no change.
  def test_timers_have_their_own_classes
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $animation = animate(10) { }
        $every = every(1) { }
        $timer = timer(1) { }
      end
    SHOES_APP
      assert_equal %w[Shoes::Animation Shoes::Every Shoes::Timer], [$animation, $every, $timer].map { |t| t.class.name }
      assert [$animation, $every, $timer].all? { |t| t.is_a?(Shoes::SubscriptionItem) }
      kinds = [$animation, $every, $timer].map { |t| drawable("id:\#{t.linkable_id}").display.shoes_type }
      assert_equal ["SubscriptionItem"] * 3, kinds
    SHOES_SPEC
  end
end
