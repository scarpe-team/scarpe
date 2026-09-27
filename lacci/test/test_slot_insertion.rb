# frozen_string_literal: true

require_relative "test_helper"

# prepend, before and after put children where the source says, and a
# display learns the position from parent.contents.index(drawable) at create
# time (DESIGN.md section 10, item 3; manual.md:2315-2323 for before/after).
class TestSlotInsertion < NienteTest
  def test_prepend_keeps_source_order
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s = stack do
          para "a"
        end
        @s.prepend do
          para "p1"
          para "p2"
        end
      end
    SHOES_APP
      assert_equal ["p1", "p2", "a"], stack.contents.map(&:text)
    SHOES_SPEC
  end

  def test_each_child_is_in_place_when_the_display_creates_it
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $create_indexes = []
        spy = Module.new do
          def create_display_drawable_for(name, id, props, parent_id:, is_widget:)
            if name == "Para"
              para = Shoes::Drawable.drawable_by_id(id)
              $create_indexes << [para.text, para.parent.contents.index(para)]
            end
            super
          end
        end
        Shoes::DisplayService.display_service.singleton_class.prepend(spy)

        @s = stack do
          para "a"
          para "b"
        end
        @s.prepend do
          para "p1"
          para "p2"
        end
      end
    SHOES_APP
      assert_equal [["a", 0], ["b", 1], ["p1", 0], ["p2", 1]], $create_indexes
    SHOES_SPEC
  end

  def test_niente_display_children_follow_the_shoes_order
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s = stack do
          para "a"
        end
        @s.prepend do
          para "p1"
          para "p2"
        end
      end
    SHOES_APP
      service = Shoes::DisplayService.display_service
      expected = stack.contents.map { |d| service.query_display_drawable_for(d.linkable_id) }
      assert_equal expected, stack.display.children
    SHOES_SPEC
  end

  def test_before_and_after
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s = stack do
          @a = para "a"
          @c = para "c"
        end
        @s.before(@c) do
          para "b1"
          para "b2"
        end
        @s.after(@c) { para "d" }
        @s.after(@a) { para "a2" }
      end
    SHOES_APP
      assert_equal ["a", "a2", "b1", "b2", "c", "d"], stack.contents.map(&:text)
    SHOES_SPEC
  end

  def test_before_needs_a_child_of_the_slot
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s = stack do
          para "inside"
        end
        @outside = para "outside"
      end
    SHOES_APP
      outsider = para("@outside").obj
      assert_raises(Shoes::Errors::InvalidAttributeValueError) do
        stack.obj.before(outsider) { }
      end
    SHOES_SPEC
  end
end
