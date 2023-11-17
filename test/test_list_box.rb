# frozen_string_literal: true

require "test_helper"

class TestListBoxShoesSpecIntegration < ShoesSpecLoggedTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

  def test_list_box_choose
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app(width: 500, height: 450) do
        para "Guess the secret word:"
        @guess_input = list_box items: ["apple", "banana", "orange"], choose: "orange"

        button "Guess" do
          guess = @guess_input.text

          if guess == "apple"
            @win.replace("Yayyy! that's right.")
          else
            @win.replace("No, better luck next time😕")
          end

          @guess_input.choose "orange"
        end

        @win = para "Will you guess it?"
      end
    SCARPE_APP
      p = para("@win")
      lb = list_box
      assert_equal "Will you guess it?", p.text

      lb.trigger_change("banana")
      assert_equal "banana", lb.text
      button.trigger_click
      assert_includes p.text, "better luck next time"

      lb.trigger_change("apple")
      assert_equal "apple", lb.text
      button.trigger_click
      assert_includes p.text, "that's right"
    TEST_CODE
  end

  def test_list_box_auto_choose_first
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        list_box items: ["apple", "banana", "orange"]
      end
    SCARPE_APP
      assert_equal "apple", list_box().chosen
    TEST_CODE
  end
end
