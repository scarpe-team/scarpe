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
