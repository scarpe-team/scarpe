# frozen_string_literal: true

require "test_helper"

# These are a variety of simple apps, and we're just making sure they don't immediately fail.

class TestWebviewScarpe < ShoesSpecLoggedTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

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
    run_test_scarpe_code(<<-'SCARPE_APP', timeout: 0.5, allow_fail: true)
      Shoes.app do
        para "Just waiting for this to time out"
      end
    SCARPE_APP
  end

  def test_button_app
    run_test_scarpe_code(<<-'SCARPE_APP', exit_immediately: true)
      Shoes.app do
        @push = button "Push me", width: 200, height: 50, top: 109, left: 132
        @note = para "Nothing pushed so far"
        @push.click { @note.replace "Aha! Click!" }
        button_id = @push.object_id
      end
    SCARPE_APP
  end

  def test_text_drawables
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

  def test_drawables_exist
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

  def test_modify_before_show
    run_test_scarpe_code(<<-'SCARPE_APP', exit_immediately: true)
      Shoes.app do
        p = para "Hello"
        p.replace("Goodbye")
      end
    SCARPE_APP
  end

  def test_download
    run_test_scarpe_code(<<-'SCARPE_APP', exit_immediately: true)
      Shoes.app do
        para "Hello"
        download("https://raw.githubusercontent.com/scarpe-team/scarpe/main/docs/static/avatar.png")
      end
    SCARPE_APP
  end

  def test_html_class_extension
    run_test_scarpe_code(<<-'SCARPE_APP', exit_immediately: true)
      Shoes.app(features: :html) do
        stack do
          para "Hello World"
          button("OK", html_class: "itsabutton")
        end
      end
    SCARPE_APP
  end

  def test_html_class_extension_fail
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE', exit_immediately: true)
      Shoes.app do
        @s = stack do
          para "Hello World"
        end
      end
    SCARPE_APP
      assert_raises Shoes::Errors::UnsupportedFeature do
        stack("@s").button("OK", html_class: "itsabutton")
      end
    TEST_CODE
  end
end