# frozen_string_literal: true

require_relative "test_helper"

# A display in another process only sees what is sent, so the path a shape
# block builds must arrive as a prop_change (DESIGN.md section 10, item 2).
class TestShape < NienteTest
  def test_shape_block_sends_its_whole_path_once
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $sent_paths = []
        Shoes::DisplayService.subscribe_to_event("prop_change", :any) do |changes, **_kwargs|
          $sent_paths << changes["shape_commands"].dup if changes.key?("shape_commands")
        end

        shape do
          move_to 10, 10
          line_to 50, 10
          line_to 30, 40
        end
      end
    SHOES_APP
      path = [["move_to", 10, 10], ["line_to", 50, 10], ["line_to", 30, 40]]
      assert_equal [path], $sent_paths
      assert_equal path, shape.display.instance_variable_get(:@shape_commands)
    SHOES_SPEC
  end

  # Shoes 3 makes the shape after its block runs and copies the pens then
  # (s3t_shape.c:290-315, COPY_PENS at :206), so `stroke color` inside the block
  # strokes that shape. curve-animation.rb drew black without this.
  def test_pens_set_inside_the_block_style_the_shape
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $sent_pens = []
        Shoes::DisplayService.subscribe_to_event("prop_change", :any) do |changes, **_kwargs|
          $sent_pens << changes["draw_context"].dup if changes.key?("draw_context")
        end

        strokewidth 3
        shape do
          move_to 0, 0
          stroke red
          nofill
          line_to 50, 10
        end
      end
    SHOES_APP
      assert_equal 1, $sent_pens.size, "the pens went out once, after the block"
      shown = $sent_pens.last
      assert_equal [255, 0, 0, 255], shown["stroke"], "the stroke set in the block reached the display"
      assert_equal [0, 0, 0, 0], shown["fill"], "and so did nofill"
      assert_equal 3, shown["strokewidth"], "the slot's pens still come through"
    SHOES_SPEC
  end

  # Ledger E11: the manual heads arc, arrow, line, oval, rect and star "» Shoes::Shape"
  # (manual 1665-1826). They answer is_a?(Shoes::Shape), and still tell the display
  # their own kind; Shoes::Shape === is left meaning the shape { } block.
  def test_art_is_a_shape_and_keeps_its_own_kind
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $made = [oval(0, 0, 5), rect(0, 0, 5), star(5, 5), line(0, 0, 5, 5), arrow(5, 5, 5), arc(0, 0, 5, 5, 0, 1)]
        shape { move_to 0, 0; line_to 5, 5 }
      end
    SHOES_APP
      $made.each do |art|
        assert art.is_a?(Shoes::Shape), "\#{art.class} is a Shoes::Shape"
        assert art.kind_of?(Shoes::Shape)
      end
      assert_equal %w[Oval Rect Star Line Arrow Arc], $made.map { |art| art.class.display_class_name }
      assert_equal 1, shapes.size, "the shape finder still means shape blocks"
    SHOES_SPEC
  end

  def test_commands_added_after_the_block_are_sent
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @shape = shape do
          move_to 0, 0
        end
      end
    SHOES_APP
      shape.obj.app { line_to 5, 5 }
      assert_equal [["move_to", 0, 0], ["line_to", 5, 5]],
        shape.display.instance_variable_get(:@shape_commands)
    SHOES_SPEC
  end
end
