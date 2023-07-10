# frozen_string_literal: true

require "test_helper"

class TestSlots < LoggedScarpeTest
  def test_stack_child
    run_test_scarpe_code(<<-'SCARPE_APP', test_code: <<-'TEST_CODE')
      Shoes.app do
        stack do
          para "Hello World"
        end
      end
    SCARPE_APP
      on_event(:next_redraw) do
        para = find_wv_widgets(Scarpe::WebviewPara)[0]
        assert para.parent.is_a?(Scarpe::WebviewStack), "A widget created in a Stack's block should be a child of the stack!"
        return_when_assertions_done
      end
    TEST_CODE
  end

  # TODO: we need to make sure that self is a Shoes::App inside the "shape do" block and that helpers work
end
