# frozen_string_literal: true

require "test_helper"

class TestWebWrangler < ScarpeTest
  # Need to make sure that even with no widgets we still get at least one redraw
  def test_empty_app
    run_test_scarpe_code(<<-'SCARPE_APP', test_code: <<-'TEST_CODE', timeout: 0.5)
      Scarpe.app do
      end
    SCARPE_APP
      on_event(:next_redraw) do
        return_when_assertions_done
      end
    TEST_CODE
  end

  # We've had problems with dirty-tracking where the DOM stops updating after
  # the first change.
  #def test_assert_multiple_dom_updates
  #  test_scarpe_code(<<-'SCARPE_APP', test_code: <<-'TEST_CODE')
  #    Shoes.app do
  #      para "Hello"
  #    end
  #  SCARPE_APP
  #    on_event(:next_redraw) do
  #      para = find_wv_widgets(Scarpe::WebviewPara)[0]
  #      with_js_dom_html do |html_text|
  #        assert html_text.include?("Hello"), "DOM HTML should include initial para text!"
  #      end.then_ruby_promise do
  #        # We'll send the signal that changes the para text, as though we called Scarpe's para.replace
  #        change = { "text_items" => [ "Goodbye" ] }
  #        doc_root.send_shoes_event(change, event_name: "prop_change", target: para.shoes_linkable_id)
  #        wrangler.promise_dom_fully_updated
  #      end.then_with_js_dom_html do |html_text|
  #        assert html_text.include?("Goodbye"), "DOM root should contain the first replacement text! Text: #{html_text.inspect}"
  #        assert !html_text.include?("Hello"), "DOM root shouldn't still contain the original text! Text: #{html_text.inspect}"
  #      end.then_ruby_promise do
  #        # We'll send the signal that changes the para text, as though we called Scarpe's para.replace
  #        change = { "text_items" => [ "Borzoi" ] }
  #        doc_root.send_shoes_event(change, event_name: "prop_change", target: para.shoes_linkable_id)
  #        wrangler.promise_dom_fully_updated
  #      end.then_with_js_dom_html do |html_text|
  #        assert html_text.include?("Borzoi"), "DOM root should contain the second replacement text! Text: #{html_text.inspect}"
  #      end.then { return_when_assertions_done }
  #    end
  #  TEST_CODE
  #end

  def with_mocked_webview(&block)
    @mocked_webview = Minitest::Mock.new
    ["puts", "scarpeAsyncEvalResult", "scarpeHeartbeat"].each do |bound_method|
      @mocked_webview.expect :bind, nil, [bound_method]
    end
    @mocked_webview.expect :init, nil, [String]
    WebviewRuby::Webview.stub :new, @mocked_webview do
      @web_wrangler = Scarpe::WebWrangler.new title: "A Window", width: 300, height: 200
      block.call
    end
    #@mocked_webview.verify
  end

  CHEAT_CONSTS = {}
  def with_running_mocked_webview(&block)
    with_mocked_webview do
      @mocked_webview.expect :set_title, nil, [String]
      @mocked_webview.expect :set_size, nil, [300, 200, 3]
      @mocked_webview.expect :navigate, nil, [String]
      @mocked_webview.expect :eval, nil, [String] # monkeypatch console

      CHEAT_CONSTS[:w_r_m_v] = {
        block: block,
        mwv: @mocked_webview,
      }

      # Webview#run is weird - it's expected to take control of the event loop
      # and not give it back until the app exits.
      class << @mocked_webview
        define_method(:run) do
          block = CHEAT_CONSTS[:w_r_m_v][:block]
          webview = CHEAT_CONSTS[:w_r_m_v][:mwv]
          block.call
          webview.expect :destroy, nil
        end
      end
      @web_wrangler.run
    end
  end

  def wrapped_js_code(js_code, eval_serial)
    Scarpe::WebWrangler.js_wrapped_code(js_code, eval_serial)
  end

  def replacement_js_code(new_body, eval_serial)
    wrapped_js_code(Scarpe::WebWrangler::DOMWrangler.replacement_code("<body>Bobo</body>"), eval_serial)
  end

  def test_ww_redraw_basic
    with_running_mocked_webview do
      # On the first call to replace, this will schedule a code replacement
      replacement_code = replacement_js_code("<body>Bobo</body>", 0)
      @mocked_webview.expect :eval, nil, [replacement_code]
      @web_wrangler.replace("<body>Bobo</body>")

      # Until WebWrangler gets an acknowledgement, it won't schedule more JS
      # We don't really care what's in this JS - these would be element modifications in real code
      @web_wrangler.dom_change("func1()")
      @web_wrangler.dom_change("func2()")
      @web_wrangler.dom_change("func3()")

      # After WebWrangler gets a success on the first update it will schedule the other ones
      update_code = wrapped_js_code("func1();func2();func3()", 1)
      @mocked_webview.expect :eval, nil, [update_code]
      @web_wrangler.send(:receive_eval_result, "success", 0, true)
    end
  end
end
