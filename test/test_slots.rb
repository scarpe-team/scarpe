# frozen_string_literal: true

require "test_helper"

class TestSlots < ShoesSpecLoggedTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

  def test_stack_child
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        stack do
          para "Hello World"
        end
      end
    SCARPE_APP
      assert_equal para.parent.linkable_id, stack.linkable_id, "A drawable created in a Stack's block should be a child of the stack!"
    TEST_CODE
  end
end
