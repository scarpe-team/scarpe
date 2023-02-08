# frozen_string_literal: true

require "test_helper"

class TestScarpe < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Scarpe::VERSION
  end

  def test_hello_world_app
    test_scarpe_app <<-'SCARPE_APP'
      para "Hello World"
      after_frame {
        do_js_eval "scarpeStatusAndExit(true);"
      }
    SCARPE_APP
  end

  def test_app_timeout
    test_scarpe_app(<<-'SCARPE_APP', timeout: 0.1, allow_fail: true)
      para "Just waiting for this to time out"
    SCARPE_APP
  end

  def test_button_app
    test_scarpe_app(<<-'SCARPE_APP', debug: true)
      @push = button "Push me", width: 200, height: 50, top: 109, left: 132
      @note = para "Nothing pushed so far"
      @push.click { @note.replace "Aha! Click!" }
      button_id = @push.object_id

      after_frame {
        # Problem with do_js_eval - if it fails completely, you get a no-op, not a failure.
        do_js_eval "val elt = getElementById(#{button_id}); if(elt.style.width != 200) { scarpeStatusAndExit(false, 'Button width is not 200!'); };"

        do_js_eval "scarpeStatusAndExit(true);"
      }
    SCARPE_APP
  end

  def test_button_args_optional
    test_scarpe_app(<<-'SCARPE_APP')
      button "Push me"
      after_frame {
        do_js_eval "scarpeStatusAndExit(true);"
      }
    SCARPE_APP
  end

  def test_stack_args_optional
    test_scarpe_app(<<-'SCARPE_APP')
      stack do
        button "Push me"
      end
      after_frame {
        do_js_eval "scarpeStatusAndExit(true);"
      }
    SCARPE_APP
  end

  def test_widgets_exist
    test_scarpe_app(<<-'SCARPE_APP')
      stack do
        para "Here I am"
        button "Push me"
        alert "I am an alert!"
        edit_line "edit_line here", width: 450
        image "http://shoesrb.com/manual/static/shoes-icon.png"
      end
      after_frame {
        do_js_eval "scarpeStatusAndExit(true);"
      }
    SCARPE_APP
  end
end
