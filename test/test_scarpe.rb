# frozen_string_literal: true

require "test_helper"

class TestScarpe < LoggedScarpeTest
  def test_that_it_has_a_version_number
    refute_nil ::Scarpe::VERSION
  end

  def test_hello_world_app
    run_test_scarpe_code(<<-'SCARPE_APP', exit_immediately: true)
      Shoes.app do
        para "Hello World"
      end
    SCARPE_APP
  end

  def test_app_timeout
    run_test_scarpe_code(<<-'SCARPE_APP', timeout: 0.1, allow_fail: true)
      Shoes.app do
        para "Just waiting for this to time out"
      end
    SCARPE_APP
  end

  def test_button_app
    run_test_scarpe_code(<<-'SCARPE_APP', debug: true, exit_immediately: true)
      Shoes.app do
        @push = button "Push me", width: 200, height: 50, top: 109, left: 132
        @note = para "Nothing pushed so far"
        @push.click { @note.replace "Aha! Click!" }
        button_id = @push.object_id
      end
    SCARPE_APP
  end

  def test_text_widgets
    run_test_scarpe_code(<<-'SCARPE_APP', exit_immediately: true)
      Shoes.app do
        para "This is plain."
        para "This has ", em("emphasis"), " and great ", strong("strength"), " and ", code("coolness"), "."
      end
    SCARPE_APP
  end

  def test_button_args_optional
    run_test_scarpe_code(<<-'SCARPE_APP', exit_immediately: true)
      Shoes.app do
        button "Push me"
      end
    SCARPE_APP
  end

  def test_stack_args_optional
    run_test_scarpe_code(<<-'SCARPE_APP', exit_immediately: true)
      Shoes.app do
        stack do
          button "Push me"
        end
      end
    SCARPE_APP
  end

  def test_widgets_exist
    run_test_scarpe_code(<<-'SCARPE_APP', exit_immediately: true)
      Shoes.app do
        stack do
          para "Here I am"
          button "Push me"
          alert "I am an alert!"
          edit_line "edit_line here", width: 450
          image "http://shoesrb.com/manual/static/shoes-icon.png"
        end
      end
    SCARPE_APP
  end
end
