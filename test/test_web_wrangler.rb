# frozen_string_literal: true

require "test_helper"

class TestWebWrangler < Minitest::Test
  def test_trivial_async_assert
    test_scarpe_code(<<-'SCARPE_APP', test_code:<<-'TEST_CODE', timeout: 0.5)
      Scarpe.app do
        para "Hello World"
      end
    SCARPE_APP
      on_event(:next_redraw) do
        assert_js("true")
        return_when_assertions_done
      end
    TEST_CODE
  end

  def test_simple_dom_html
    test_scarpe_code(<<-'SCARPE_APP', test_code:<<-'TEST_CODE')
      Scarpe.app do
        para "Hello World"
      end
    SCARPE_APP
      # This prints messages whenever schedulers or executors raise exceptions in Promises
      Scarpe::Promise.debug = true

      on_event(:next_redraw) do
        para = find_widgets(Scarpe::Para)[0]

        with_js_dom_html do |html_text|
          assert html_text.include?("Hello World"), "DOM root should contain the text Hello World!"
        end.then_ruby_promise { para.replace("goodbye world"); para.promise_update }.then_with_js_dom_html do |html_text|
          assert html_text.include?("goodbye world"), "DOM root should contain the replacement text goodbye world! Text: #{html_text.inspect}"
          assert !html_text.include?("Hello World"), "DOM root shouldn't still contain the original text Hello World! Text: #{html_text.inspect}"
        end.then { return_when_assertions_done }
      end
    TEST_CODE
  end
end
