# frozen_string_literal: true

require "test_helper"

class TestWebWrangler < Minitest::Test
  # We've had problems with dirty-tracking where the DOM stops updating after
  # the first change.
  def test_assert_multiple_dom_updates
    test_scarpe_code(<<-'SCARPE_APP', test_code: <<-'TEST_CODE')
      Shoes.app do
        para "Hello"
      end
    SCARPE_APP
      on_event(:next_redraw) do
        para = find_wv_widgets(Scarpe::WebviewPara)[0]
        with_js_dom_html do |html_text|
          assert html_text.include?("Hello"), "DOM HTML should include initial para text!"
        end.then_ruby_promise do
          # We'll send the signal that changes the para text, as though we called Scarpe's para.replace
          change = { "text_items" => [ "Goodbye" ] }
          doc_root.send_shoes_event(change, event_name: "prop_change", target: para.shoes_linkable_id)
          wrangler.promise_dom_fully_updated
        end.then_with_js_dom_html do |html_text|
          assert html_text.include?("Goodbye"), "DOM root should contain the first replacement text! Text: #{html_text.inspect}"
          assert !html_text.include?("Hello"), "DOM root shouldn't still contain the original text! Text: #{html_text.inspect}"
        end.then_ruby_promise do
          # We'll send the signal that changes the para text, as though we called Scarpe's para.replace
          change = { "text_items" => [ "Borzoi" ] }
          doc_root.send_shoes_event(change, event_name: "prop_change", target: para.shoes_linkable_id)
          wrangler.promise_dom_fully_updated
        end.then_with_js_dom_html do |html_text|
          assert html_text.include?("Borzoi"), "DOM root should contain the second replacement text! Text: #{html_text.inspect}"
        end.then { return_when_assertions_done }
      end
    TEST_CODE
  end
end
