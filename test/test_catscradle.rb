# frozen_string_literal: true

require "test_helper"

# Tests for the CatsCradle testing language
class TestCatsCradle < LoggedScarpeTest
  def test_para_finder
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        para "Hello World"
      end
    SCARPE_APP
      on_heartbeat do
        assert_include para().text_items[0], "Hello"

        test_finished
      end
    TEST_CODE
  end

  def test_global_para
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        $p = para "Hello World"
      end
    SCARPE_APP
      on_heartbeat do
        assert_include para(:$p).text_items[0], "Hello"
        assert_include $p.text_items[0], "Hello"

        test_finished
      end
    TEST_CODE
  end

  def test_para_replace
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        para "Hello World"
      end
    SCARPE_APP
      on_heartbeat do
        p = para()
        assert_include p.display.to_html, "Hello"
        p.replace("Goodbye World")
        assert_not_include p.display.to_html, "Hello"
        assert_include p.display.to_html, "Goodbye"

        test_finished
      end
    TEST_CODE
  end

  def test_html_dom_replace
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        para "Hello World"
      end
    SCARPE_APP
      on_heartbeat do
        p = para()
        assert_include dom_html, "Hello World"
        p.replace("Goodbye World")
        wait fully_updated
        # It would be more efficient to grab the dom_html fewer times and assign it.
        # But this is meant to be testing the API and control flow. So: multiple times.
        assert_include dom_html, "Goodbye World"
        assert_not_include dom_html, "Hello World"

        test_finished
      end
    TEST_CODE
  end

  def test_html_dom_multiple_update
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        para "Hello World"
      end
    SCARPE_APP
      on_heartbeat do
        p = para()
        assert_include dom_html, "Hello World"
        p.replace("Goodbye World")
        wait fully_updated
        assert_include dom_html, "Goodbye World"
        p.replace("Hello Again")
        wait fully_updated
        assert_include dom_html, "Hello Again"

        test_finished
      end
    TEST_CODE
  end

  def test_event_from_js_handler
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        $p = para "Hello"
        button "Press Me" do
          $p.replace "Goodbye"
        end
      end
    SCARPE_APP
      on_heartbeat do
        b = button()
        snippet = button.display.handler_js_code("click")
        query_js_value(snippet) # Run the snippet
        wait fully_updated
        html_text = dom_html
        assert_include html_text, "Goodbye"
        assert_not_include html_text, "Hello"

        test_finished
      end
    TEST_CODE
  end
end

# How to get this to work with relay-display?
