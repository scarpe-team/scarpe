# frozen_string_literal: true

require "test_helper"

# Test WebWrangler and its weird, involved testing language.
# This may go away over time as CatsCradle gets more capable.

class TestWebWranglerInScarpeApp < ShoesSpecLoggedTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

  # Need to make sure that even with no drawables we still get at least one redraw
  def test_empty_app
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE', timeout: 5.0)
      Shoes.app do
      end
    SCARPE_APP
      catscradle_dsl do
        on_event(:next_redraw) do
          test_finished
        end
      end
    TEST_CODE
  end

  # When the Display Service side sends a destroy event, everything should shut down.
  def test_destroy_from_display_service
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        para "Hello"
      end
    SCARPE_APP
      Shoes::DisplayService.dispatch_event("destroy", nil)
    TEST_CODE
  end
end

class TestWebWranglerMocked < LoggedScarpeTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

  def with_mocked_webview(wrangler_opts: {}, &block)
    @mocked_webview = Minitest::Mock.new
    ["puts", "scarpeAsyncEvalResult", "scarpeHeartbeat"].each do |bound_method|
      @mocked_webview.expect :bind, nil, [bound_method]
    end
    @mocked_webview.expect :init, nil, [String]
    WebviewRuby::Webview.stub :new, @mocked_webview do
      @web_wrangler = Scarpe::Webview::WebWrangler.new title: "A Window", width: 300, height: 200, **wrangler_opts
      block.call
    end
    @mocked_webview.verify
  end

  CHEAT_CONSTS = {}
  def with_running_mocked_webview(wrangler_opts: {}, &block)
    with_mocked_webview(wrangler_opts:) do
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
      @web_wrangler.empty_page = CALZINI_EMPTY_PAGE
      @web_wrangler.run
    end
  end

  def wrapped_js_code(js_code, eval_serial)
    Scarpe::Webview::WebWrangler.js_wrapped_code(js_code, eval_serial)
  end

  def replacement_js_code(new_body, eval_serial)
    wrapped_js_code(Scarpe::Webview::WebWrangler::DOMWrangler.replacement_code(new_body), eval_serial)
  end

  def test_ww_draw_body
    with_running_mocked_webview do
      # On the first call to replace, this will schedule a code replacement
      replacement_code = replacement_js_code("<body>Bobo</body>", 0)
      @mocked_webview.expect :eval, nil, [replacement_code]
      @web_wrangler.replace("<body>Bobo</body>")

      @web_wrangler.send(:receive_eval_result, "success", 0, true)
      assert @web_wrangler.dom_fully_updated?, "DOM should be fully_updated with body in place and no updates!"
    end
  end

  def test_ww_redraw_basic
    with_running_mocked_webview do
      new_body_code = "<body>Bobo</body>"
      # On the first call to replace, this will schedule a code replacement
      replacement_code = replacement_js_code(new_body_code, 0)
      @mocked_webview.expect :eval, nil, [replacement_code]
      @web_wrangler.replace(new_body_code)

      # Until WebWrangler gets an acknowledgement, it won't schedule more JS
      # We don't really care what's in this JS - these would be element modifications in real code
      @web_wrangler.dom_change("func1()")

      # After WebWrangler gets a success on the first update it will schedule the other ones
      update_code = wrapped_js_code("func1()", 1)
      @mocked_webview.expect :eval, nil, [update_code]
      @web_wrangler.send(:receive_eval_result, "success", 0, true)

      @web_wrangler.send(:receive_eval_result, "success", 1, true)
      assert @web_wrangler.dom_fully_updated?, "DOM should be fully_updated with body in place and update finished!"
    end
  end

  def test_ww_redraw_multi
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

  def test_ww_redraw_fully_updated
    with_running_mocked_webview do
      assert @web_wrangler.dom_fully_updated?, "DOM should be fully_updated before any calls!"

      new_body_code = "<body>Bobo</body>"
      # On the first call to replace, this will schedule a code replacement
      replacement_code = replacement_js_code(new_body_code, 0)
      @mocked_webview.expect :eval, nil, [replacement_code]
      @web_wrangler.replace(new_body_code)
      promise = @web_wrangler.promise_dom_fully_updated

      assert !@web_wrangler.dom_fully_updated?, "DOM should not be fully_updated before body in place!"
      assert !promise.complete?, "Fully-updated promise should not be fulfilled before everything is done!"

      # Until WebWrangler gets an acknowledgement, it won't schedule more JS
      # We don't really care what's in this JS - these would be element modifications in real code
      @web_wrangler.dom_change("func1()")
      @web_wrangler.dom_change("func2()")

      assert !@web_wrangler.dom_fully_updated?, "DOM should not be fully_updated with requested updates!"
      assert !promise.complete?, "Fully-updated promise should not be fulfilled before everything is done! (2)"

      # After WebWrangler gets a success on the first update it will schedule the other ones
      update_code = wrapped_js_code("func1();func2()", 1)
      @mocked_webview.expect :eval, nil, [update_code]
      @web_wrangler.send(:receive_eval_result, "success", 0, true)

      assert !@web_wrangler.dom_fully_updated?, "DOM should not be fully_updated between updates!"

      @web_wrangler.dom_change("func3()")
      update_code = wrapped_js_code("func3()", 2)
      @mocked_webview.expect :eval, nil, [update_code]
      @web_wrangler.send(:receive_eval_result, "success", 1, true)

      assert !@web_wrangler.dom_fully_updated?, "DOM should not be fully_updated before last success callback!"

      @web_wrangler.send(:receive_eval_result, "success", 2, true)

      assert @web_wrangler.dom_fully_updated?, "DOM should be fully_updated after all success callbacks finished!"
      assert_equal :fulfilled, promise.state, "Fully-updated promise should be fulfilled once all updates complete!"
    end
  end

  def test_ww_redraw_promises
    with_running_mocked_webview do
      new_body_code = "<body>Bobo</body>"
      # On the first call to replace, this will schedule a code replacement
      replacement_code = replacement_js_code(new_body_code, 0)
      @mocked_webview.expect :eval, nil, [replacement_code]
      body_promise = @web_wrangler.replace(new_body_code)

      assert !body_promise.complete?, "Body promise should stay pending until body is updated"

      # These two update promises will be the same object, but that's an implementation detail.
      update_p1 = @web_wrangler.dom_change("func1()")
      update_p2 = @web_wrangler.dom_change("func2()")

      assert !body_promise.complete?, "Body promise should stay pending until body is updated (2)"
      assert !update_p1.complete?, "Update promise should stay pending until update is finished"
      assert !update_p2.complete?, "Update promise(2) should stay pending until update is finished"

      # After WebWrangler gets a success on the first update it will schedule the other ones
      update_code = wrapped_js_code("func1();func2()", 1)
      @mocked_webview.expect :eval, nil, [update_code]
      @web_wrangler.send(:receive_eval_result, "success", 0, true)

      assert_equal :fulfilled, body_promise.state, "Body promise should be complete when body is updated"
      assert !update_p1.complete?, "Update promise should stay pending until update is finished (2)"

      update_p3 = @web_wrangler.dom_change("func3()")

      assert !update_p3.complete?, "Second-update promise should stay pending until update is finished"

      update_code = wrapped_js_code("func3()", 2)
      @mocked_webview.expect :eval, nil, [update_code]
      @web_wrangler.send(:receive_eval_result, "success", 1, true)

      assert_equal :fulfilled, update_p1.state, "Update promise should be fulfilled after update is finished (2)"
      assert_equal :fulfilled, update_p2.state, "Update promise(2) should be fulfilled after update is finished (2)"
      assert !update_p3.complete?, "Second-update promise should stay pending until update is finished (2)"

      @web_wrangler.send(:receive_eval_result, "success", 2, true)

      assert_equal :fulfilled, update_p3.state, "Update promise should be fulfilled after update is finished (2)"
    end
  end

  CALZINI_EMPTY_PAGE = <<~HTML
    <html>
      <head id='head-wvroot'>
        <style id='style-wvroot'>
          /** Style resets **/
          body {
            font-family: arial, Helvetica, sans-serif;
            margin: 0;
            height: 100%;
            overflow: hidden;
          }
          p {
            margin: 0;
          }
        </style>
      </head>
      <body id='body-wvroot'>
        <div id='wrapper-wvroot'></div>
      </body>
    </html>
  HTML
end

class TestWebWranglerAsyncJS < ShoesSpecLoggedTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

  def round_trip_app(how_many)
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-TEST_CODE)
      Shoes.app do
        para "Hello"
      end
    SCARPE_APP
      catscradle_dsl do
        on_event(:next_redraw) do
          num_times = #{how_many}

          p = query_js_promise("document.tests = {}")
          num_times.times do |i|
            next_p = p.on_fulfilled do
              query_js_promise("document.tests[\#{i}] = true")
            end
            p = next_p
          end
          wait p

          tests_hash = query_js_value("document.tests")

          expected_value = {}
          num_times.times { |i| expected_value[i.to_s] = true }
          assert_equal expected_value, tests_hash
          test_finished
        end
      end
    TEST_CODE
  end

  def test_many_round_trips
    round_trip_app(30)
  end

  5.times do |i|
    define_method("test_many_app_starts_#{i}") do
      round_trip_app(5)
    end
  end
end
