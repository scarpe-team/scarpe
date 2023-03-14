# frozen_string_literal: true

require "test_helper"

class TestScarpeNoDisplay < Minitest::Test
  def setup
    # If we want to be sure we hit a particular line, we can set a boolean when we do.
    # An assertion is usually better... But an assertion doesn't work if we might not
    # execute the line at all.
    TEST_DATA.clear
  end

  # make sure the test code actually gets called at all
  def test_app_created
    test_scarpe_code_no_display(<<~'SCARPE_APP', <<~'TEST_CODE')
      Scarpe.app do
        para 'hello world'
      end
    SCARPE_APP
      the_app = self
      on_init do
        TEST_DATA[:got_here] = true
        the_app.destroy
      end
    TEST_CODE
    assert_equal true, TEST_DATA[:got_here]
  end

  def test_run_event
    test_scarpe_code_no_display(<<~'SCARPE_APP', <<~'TEST_CODE')
      Scarpe.app do
        para 'hello world'
      end
    SCARPE_APP
      the_app = self
      bind_display_event(event_name: "run") do
        TEST_DATA[:got_here] = true
        the_app.destroy
      end
    TEST_CODE
    assert_equal true, TEST_DATA[:got_here]
  end

  def test_first_heartbeat
    test_scarpe_code_no_display(<<~'SCARPE_APP', <<~'TEST_CODE')
      Scarpe.app do
        para 'hello world'
      end
    SCARPE_APP
      the_app = self
      on_next_heartbeat do
        TEST_DATA[:got_here] = true
        the_app.destroy
      end
    TEST_CODE
    assert_equal true, TEST_DATA[:got_here]
  end

  def test_para_replace
    test_scarpe_code_no_display(<<~'SCARPE_APP', <<~'TEST_CODE')
      Scarpe.app do
        para 'hello world'
      end
    SCARPE_APP
      the_app = self
      para = nil
      # During init, no widgets have yet been created. So that's too early to find our para.
      on_next_heartbeat do
        para = find_widgets_by(Scarpe::Para)[0]
        para.replace("goodbye world")

        # A replace doesn't actually take a hearbeat to happen, but we're testing event handling.
        on_next_heartbeat do
          if para.text_items == ["goodbye world"]
            TEST_DATA[:got_here] = true
            the_app.destroy
          else
            raise "Expected para.text_children to equal ['goodbye world']!"
          end
        end
      end
    TEST_CODE
    assert_equal true, TEST_DATA[:got_here]
  end

  def test_the_test_block
    TEST_DATA[:the_test] = self
    @got_here = false
    test_scarpe_code_no_display(<<~'SCARPE_APP', <<~'TEST_CODE')
      Scarpe.app do
        para 'hello world'
      end
    SCARPE_APP
      the_app = self
      para = nil
      # During init, no widgets have yet been created. So that's too early to find our para.
      on_next_heartbeat do
        para = find_widgets_by(Scarpe::Para)[0]
        para.replace("goodbye world")

        TEST_DATA[:the_test].instance_eval do
          @got_here = true
        end
        the_app.destroy
      end
    TEST_CODE
    assert_equal true, @got_here
  end
end
