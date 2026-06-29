# frozen_string_literal: true

require_relative "test_helper"

class TestParenting < NienteTest
  def test_simple_button
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        button "OK"
      end
    SHOES_APP
      # Test that Lacci has set parents properly
      doc_root = button().parent
      assert_equal Shoes::DocumentRoot, doc_root.class
      assert_equal [button().obj], doc_root.contents

      # Test that Niente has set parents properly
      assert_equal "DocumentRoot", button().display.parent.shoes_type
    SHOES_SPEC
  end

  def test_button_in_stack
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        stack do
          button "OK"
        end
      end
    SHOES_APP
      # Test that Lacci has set parents properly
      assert_equal Shoes::DocumentRoot, stack().parent.class
      assert_equal Shoes::Stack, button().parent.class
      assert_equal [button().obj], stack().contents

      # Test that Niente has set parents properly
      assert_equal "DocumentRoot", stack().display.parent.shoes_type
      assert_equal "Stack", button().display.parent.shoes_type
      assert_equal [button().display], stack().display.children
    SHOES_SPEC
  end

  # We had a bug with this. It wasn't setting @children properly.
  def test_clear_with_no_contents
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s = stack do
        end
        button "Clear" do
          @s.clear do
            para "cleared"
          end
        end
      end
    SHOES_APP
      button().trigger_click
      assert_equal "cleared", para.text
    SHOES_SPEC
  end

  def test_stack_clear
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s = stack do
          @p = para "Here"
        end
        button "Clear" do
          @s.clear
        end
      end
    SHOES_APP
      button.trigger_click
      assert_equal [], stack.contents
    SHOES_SPEC
  end

  def test_drawable_remove
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s = stack do
          @p = para "Here"
        end
        button "Clear" do
          @p.remove
        end
      end
    SHOES_APP
      p = para # grab it while it's still there
      button.trigger_click
      assert_equal [], stack.contents
      assert_nil p.parent
    SHOES_SPEC
  end

  # Regression: clearing a slot must unregister its WHOLE subtree from the
  # class-level Shoes::Drawable registry, not just its direct children. Before
  # the cascading Slot#destroy fix, nested descendants (the para/button inside
  # an inner stack) stayed pinned in @drawables_by_id forever, leaking on every
  # clear { ... } rebuild — fatal for long-running apps (Clock, Pong, dashboards).
  def test_clear_unregisters_nested_descendants
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @outer = stack do
          stack do            # inner slot; its children are GRANDCHILDREN of @outer
            @deep_para = para "deep"
            @deep_btn  = button "deep btn"
          end
        end
        @clear = button "Clear" do
          @outer.clear
        end
      end
    SHOES_APP
      # Grab the deep descendants' registry keys while they still exist.
      deep_para_id = para("@deep_para").obj.linkable_id
      deep_btn_id  = button("@deep_btn").obj.linkable_id

      # Sanity: they're registered before the clear.
      refute_nil Shoes::Drawable.drawable_by_id(deep_para_id, none_ok: true)
      refute_nil Shoes::Drawable.drawable_by_id(deep_btn_id, none_ok: true)

      button("@clear").trigger_click

      # Outer slot empties out...
      assert_equal [], stack("@outer").contents
      # ...and the nested descendants are no longer pinned in the registry.
      assert_nil Shoes::Drawable.drawable_by_id(deep_para_id, none_ok: true),
        "nested para leaked in the drawable registry after clear"
      assert_nil Shoes::Drawable.drawable_by_id(deep_btn_id, none_ok: true),
        "nested button leaked in the drawable registry after clear"
    SHOES_SPEC
  end

  # I don't think Shoes does this. We have to use Lacci-specific methods.
  # It's still good to have a test for it.
  def test_drawable_reparent
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s1 = stack do
          @p = para "Move me"
        end

        @s2 = stack do
        end

        button "Move It!" do
          @p.set_parent(@s2)
        end
      end
    SHOES_APP
      button.trigger_click

      # Check parents in Lacci
      assert_equal [], stack("@s1").contents
      assert_equal stack("@s2").obj, para.parent
      assert_equal [para.obj], stack("@s2").contents

      # Check parents in Niente
      assert_equal [], stack("@s1").display.children
      assert_equal stack("@s2").display, para.display.parent
      assert_equal [para.display], stack("@s2").display.children
    SHOES_SPEC
  end

  def test_add_to_non_current_slot
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s = stack do
        end
        button "Add a Button" do
          @ok_button = @s.button "OK"
        end
      end
    SHOES_APP
      button.trigger_click
      assert_equal [button("@ok_button").obj], stack.contents
      assert_equal stack.obj, button("@ok_button").parent
    SHOES_SPEC
  end
end
