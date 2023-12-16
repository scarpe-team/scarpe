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
