# frozen_string_literal: true

require_relative "helper"

class ViewLifecycleTest < Minitest::Test
  include NativeTestHelpers

  APP = <<~RUBY.freeze
    Shoes.app do
      @removed = stack { @nested = stack { @old = para "old" } }
      @live = para "live"
    end
  RUBY

  def test_removing_a_slot_clears_its_descendants_cached_metadata
    run = run_app(APP, test_code: <<~TEST)
      service = Scarpe::Native::DisplayService.instance
      removed = [stack("@removed").linkable_id, stack("@nested").linkable_id, para("@old").linkable_id]
      old_id = para("@old").linkable_id
      live_id = para("@live").linkable_id
      rect = [10, 20, 100, 30, 30]
      service.receive("t" => "layout", "rects" => (removed + [live_id]).map { |id| [id, *rect] })
      [old_id, live_id].each do |id|
        service.receive("t" => "para_hit", "id" => id, "value" => 2)
        Shoes::DisplayService.para_cursor_top_cache[id] = 12
      end
      removed.each { |id| assert_equal rect, Shoes::DisplayService.layout_cache[id] }
      assert_equal 2, Shoes::DisplayService.para_hit_cache[old_id]

      stack("@removed").remove

      removed.each { |id| refute Shoes::DisplayService.layout_cache.key?(id) }
      refute Shoes::DisplayService.para_hit_cache.key?(old_id), "removed paragraphs release cached hit-test results"
      refute Shoes::DisplayService.para_cursor_top_cache.key?(old_id), "removed paragraphs release cached caret positions"
      assert_equal rect, Shoes::DisplayService.layout_cache[live_id]
      assert_equal 2, Shoes::DisplayService.para_hit_cache[live_id]
      assert_equal 12, Shoes::DisplayService.para_cursor_top_cache[live_id]
    TEST
    assert_spec_passed(run)
  end

  def test_late_layout_replies_only_update_live_views
    run = run_app(APP, test_code: <<~TEST)
      service = Scarpe::Native::DisplayService.instance
      old_id = para("@old").linkable_id
      live_id = para("@live").linkable_id
      para("@old").remove

      rect = [20, 30, 120, 40, 40]
      service.receive("t" => "layout", "rects" => [[old_id, *rect], [live_id, *rect]])

      refute Shoes::DisplayService.layout_cache.key?(old_id), "late layout replies must not restore removed IDs"
      assert_equal rect, Shoes::DisplayService.layout_cache[live_id]
    TEST
    assert_spec_passed(run)
  end

  def test_late_hit_replies_only_update_live_paragraphs
    run = run_app(APP, test_code: <<~TEST)
      service = Scarpe::Native::DisplayService.instance
      old_id = para("@old").linkable_id
      live_id = para("@live").linkable_id
      para("@old").remove

      service.receive("t" => "para_hit", "id" => old_id, "value" => 3)
      service.receive("t" => "para_hit", "id" => live_id, "value" => 0)

      refute Shoes::DisplayService.para_hit_cache.key?(old_id), "late hit-test replies must not restore removed IDs"
      assert_equal 0, Shoes::DisplayService.para_hit_cache[live_id]
      service.receive("t" => "para_hit", "id" => live_id, "value" => nil)
      assert_nil Shoes::DisplayService.para_hit_cache[live_id]
    TEST
    assert_spec_passed(run)
  end
end
