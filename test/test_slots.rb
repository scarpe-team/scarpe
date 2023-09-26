# frozen_string_literal: true

require "test_helper"

class TestSlots < LoggedScarpeTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

  def test_stack_child
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        stack do
          para "Hello World"
        end
      end
    SCARPE_APP
      on_next_redraw do
        assert para.parent.is_a?(Shoes::Stack), "A widget created in a Stack's block should be a child of the stack!"
        test_finished
      end
    TEST_CODE
  end
end
