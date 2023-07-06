# frozen_string_literal: true

require "test_helper"

class TestEditBox < LoggedScarpeTest
  def test_renders_textarea
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        edit_box "Hello, World!"
      end
    SCARPE_APP
      on_heartbeat do
        box = edit_box
        html_id = box.display.html_id
        assert_html edit_box.display.to_html, :textarea, id: html_id, oninput: "scarpeHandler('#{box.display.shoes_linkable_id}-change', this.value)" do
          "Hello, World!"
        end

        test_finished
      end
    TEST_CODE
  end

  def test_renders_textarea_content_block
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        edit_box { "Hello, World!" }
      end
    SCARPE_APP
      on_heartbeat do
        box = edit_box
        html_id = box.display.html_id
        assert_html edit_box.display.to_html, :textarea, id: html_id, oninput: "scarpeHandler('#{box.display.shoes_linkable_id}-change', this.value)" do
          "Hello, World!"
        end

        test_finished
      end
    TEST_CODE
  end

  def test_textarea_width
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        edit_box "Hello, World!", width: 100, height: 120
      end
    SCARPE_APP
      on_heartbeat do
        box = edit_box
        html_id = box.display.html_id
        assert_html edit_box.display.to_html,
          :textarea,
          id: html_id,
          oninput: "scarpeHandler('#{box.display.shoes_linkable_id}-change', this.value)",
          style: "height:120px;width:100px" do
          "Hello, World!"
        end

        test_finished
      end
    TEST_CODE
  end

  # TODO: look into how to trigger a JS change event using document.dispatchEvent?

  # Amusingly, this hits a Webview bug. You can do the same thing in the console.
  # The value updates, including on the screen, but querying the innerHTML of the
  # enclosing element shows the *old* value, not the new one.
  #def test_textarea_widget_change
  #  run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
  #    Shoes.app do
  #      edit_box "Hello, World!"
  #    end
  #  SCARPE_APP
  #    on_heartbeat do
  #      edit_box.text = "Justified Unicorn Homicide is the best band name"
  #      wait fully_updated
  #      assert_include dom_html, "Justified Unicorn Homicide"
  #
  #      test_finished
  #    end
  #  TEST_CODE
  #end
end
