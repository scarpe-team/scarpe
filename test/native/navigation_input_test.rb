# frozen_string_literal: true

require_relative "helper"

class NavigationInputTest < Minitest::Test
  include NativeTestHelpers

  def test_navigation_keys_reach_ruby_as_symbols_while_editing
    skip_without_real_binary
    run = run_real(<<~APP, test_code: <<~TEST)
      Shoes.app do
        $navigation_keys = []
        edit_line "Keep this text"
        keypress { |key| $navigation_keys << key }
      end
    APP
      click_on edit_line
      press_key :browser_back
      press_key :browser_forward
      assert_equal [:browser_back, :browser_forward], $navigation_keys
      assert_equal "Keep this text", edit_line.text
    TEST
    assert_spec_passed(run)
  end
end
