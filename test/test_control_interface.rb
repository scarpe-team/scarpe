# frozen_string_literal: true

require "test_helper"

class TestControlInterface < LoggedScarpeTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

  def test_trivial_async_assert
    run_test_scarpe_code(<<-'SCARPE_APP', test_code: <<-'TEST_CODE')
      Shoes.app do
        para "Hello World"
      end
    SCARPE_APP
      on_event(:next_redraw) do
        assert_js("true") # Note that this is an async assert - doesn't check immediately!
        return_when_assertions_done
      end
    TEST_CODE
  end

  def test_assert_dom_html
    run_test_scarpe_code(<<-'SCARPE_APP', test_code: <<-'TEST_CODE')
      Shoes.app do
        para "Hello World"
      end
    SCARPE_APP
      on_event(:next_redraw) do
        with_js_dom_html do |html_text|
          assert html_text.include?("Hello World"), "DOM root should contain the text Hello World!"
        end.then { return_when_assertions_done }
      end
    TEST_CODE
  end

  def test_assert_widget
    run_test_scarpe_code(<<-'SCARPE_APP', test_code: <<-'TEST_CODE')
      Shoes.app do
        para "Hello World"
      end
    SCARPE_APP
      on_event(:next_redraw) do
        para = find_wv_widgets(Scarpe::WebviewPara)[0]
        assert para
        return_when_assertions_done
      end
    TEST_CODE
  end

  def test_assert_dom_html_update
    run_test_scarpe_code(<<-'SCARPE_APP', test_code: <<-'TEST_CODE')
      Shoes.app do
        para "Hello World"
      end
    SCARPE_APP
      on_event(:next_redraw) do
        para = find_wv_widgets(Scarpe::WebviewPara)[0]
        with_js_dom_html do |html_text|
          assert html_text.include?("Hello World"), "DOM root should contain the text Hello World!"
        end.then_ruby_promise do
          # We'll send the signal that changes the para text, as though we called Scarpe's para.replace
          change = { "text_items" => [ "Goodbye World" ] }
          doc_root.send_shoes_event(change, event_name: "prop_change", target: para.shoes_linkable_id)
          wrangler.promise_dom_fully_updated
        end.then_with_js_dom_html do |html_text|
        	assert html_text.include?("Goodbye World"), "DOM root should contain the replacement text goodbye world! Text: #{html_text.inspect}"
        	assert !html_text.include?("Hello World"), "DOM root shouldn't still contain the original text Hello World! Text: #{html_text.inspect}"
        end.then { return_when_assertions_done }
      end
    TEST_CODE
  end
end
