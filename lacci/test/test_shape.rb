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
