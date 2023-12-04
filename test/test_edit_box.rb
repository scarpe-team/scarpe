# frozen_string_literal: true

require "test_helper"

class TestEditBoxShoesSpec < ShoesSpecLoggedTest
  self.logger_dir = File.expand_path "#{__dir__}/../logger"

  def test_renders_textarea
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        edit_box "Hello, World!"
      end
    SCARPE_APP
      box_disp = edit_box.display
      assert_contains_html box_disp.to_html, :textarea, id: box_disp.html_id, oninput: "scarpeHandler('#{box_disp.shoes_linkable_id}-change', this.value)" do
        "Hello, World!"
      end
    TEST_CODE
  end

  def test_renders_textarea_no_change_cb_on_manual_replace
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        @p = para "Yo!"
        edit_box { @p.replace "Double Yo!" }
      end
    SCARPE_APP
      box = edit_box
      box.text = "Awwww yeah"
      html_id = box.display.html_id
      assert_contains_html edit_box.display.to_html, :textarea, id: html_id, oninput: "scarpeHandler('#{box.display.shoes_linkable_id}-change', this.value)" do
        "Awwww yeah"
      end
      # Shoes3 does *not* fire a change event when manually replacing text
      assert !para.display.to_html.include?("Double Yo!")
    TEST_CODE
  end

  def test_textarea_width
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        edit_box "Hello, World!", width: 100, height: 120
      end
    SCARPE_APP
      box = edit_box
      html_id = box.display.html_id
      assert_contains_html edit_box.display.to_html,
        :textarea,
        id: html_id,
        oninput: "scarpeHandler('#{box.display.shoes_linkable_id}-change', this.value)",
        style: "height:120px;width:100px" do
        "Hello, World!"
      end
    TEST_CODE
  end

  # TODO: look into how to trigger a JS change event using document.dispatchEvent?

  # Amusingly, this hits a Webview bug. You can do the same thing in the console.
  # The value updates, including on the screen, but querying the innerHTML of the
  # enclosing element shows the *old* value, not the new one.
  #def test_textarea_drawable_change
  #  run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
  #    Shoes.app do
  #      edit_box "Hello, World!"
  #    end
  #  SCARPE_APP
  #    edit_box.text = "Justified Unicorn Homicide is the best band name"
  #    assert_includes dom_html, "Justified Unicorn Homicide"
  #  TEST_CODE
  #end
end
