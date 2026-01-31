# frozen_string_literal: true

require_relative "test_helper"

class TestLacci < NienteTest
  def test_simple_button_click
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @b = button "OK" do
          @b.text = "Yup"
        end
      end
    SHOES_APP
      button().trigger_click
      assert_equal "Yup", button().text
    SHOES_SPEC
  end

  def test_positional_default_values
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        star 15, 35
      end
    SHOES_APP
      s = star()
      assert_equal 10, s.points
      assert_equal 50, s.inner
    SHOES_SPEC
  end

  def test_positional_args
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        star 10, 25, 8 # Leave outer and inner as default
      end
    SHOES_APP
      s = star()
      assert_equal 10, s.left
      assert_equal 25, s.top
      assert_equal 8, s.points
      assert_equal 50, s.inner
    SHOES_SPEC
  end

  def test_keyword_args
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        star 5, 6, points: 8, inner: 30
      end
    SHOES_APP
      s = star()
      assert_equal 5, s.left
      assert_equal 6, s.top
      assert_equal 8, s.points
      assert_equal 100, s.outer
      assert_equal 30, s.inner
    SHOES_SPEC
  end

  def test_too_many_positional_args
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s = stack {}
      end
    SHOES_APP
      s = stack("@s")
      assert_raises Shoes::Errors::BadArgumentListError do
        s.star 5, 6, 7, 8, 9, 10, 11
      end
    SHOES_SPEC
  end

  def test_too_few_positional_args
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s = stack {}
      end
    SHOES_APP
      s = stack("@s")
      assert_raises Shoes::Errors::BadArgumentListError do
        s.star 5
      end
    SHOES_SPEC
  end

  def test_mouse_returns_default_state
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @m = self.mouse
      end
    SHOES_APP
      m = Shoes.APPS[0].instance_variable_get(:@m)
      assert_equal [0, 0, 0], m
    SHOES_SPEC
  end

  def test_window_as_shoes_app
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      window :title => "Test Window", :width => 500, :height => 300 do
        @p = para "Window works!"
      end
    SHOES_APP
      assert_equal "Window works!", para().text
    SHOES_SPEC
  end

  def test_app_width_height_accessible
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app :width => 600, :height => 400 do
        @w = self.width
        @h = self.height
      end
    SHOES_APP
      w = Shoes.APPS[0].instance_variable_get(:@w)
      h = Shoes.APPS[0].instance_variable_get(:@h)
      assert_equal 600, w
      assert_equal 400, h
    SHOES_SPEC
  end

  def test_mouse_reflects_display_service_state
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        Shoes::DisplayService.mouse_state = [1, 150, 200]
        @m = self.mouse
      end
    SHOES_APP
      m = Shoes.APPS[0].instance_variable_get(:@m)
      assert_equal [1, 150, 200], m
    SHOES_SPEC
  end

  def test_builtin_response_mechanism
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "test"
      end
    SHOES_APP
      # Test the builtin response mechanism directly
      Shoes::DisplayService.clear_builtin_response
      assert_nil Shoes::DisplayService.consume_builtin_response

      Shoes::DisplayService.set_builtin_response("hello")
      assert_equal "hello", Shoes::DisplayService.consume_builtin_response

      # Should be consumed (nil on second read)
      assert_nil Shoes::DisplayService.consume_builtin_response
    SHOES_SPEC
  end

  def test_builtin_response_false_value
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "test"
      end
    SHOES_APP
      # false is a valid response (e.g. confirm returning false)
      Shoes::DisplayService.clear_builtin_response
      Shoes::DisplayService.set_builtin_response(false)
      result = Shoes::DisplayService.consume_builtin_response
      assert_equal false, result
    SHOES_SPEC
  end

  def test_clipboard_accessor
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "test"
      end
    SHOES_APP
      app = Shoes.APPS[0]
      # clipboard should return a string (may be empty)
      result = app.clipboard
      assert_kind_of String, result

      # clipboard= should accept a string
      app.clipboard = "scarpe test"
      assert_equal "scarpe test", app.clipboard
    SHOES_SPEC
  end

  def test_shoes_builtin_returns_response
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "test"
      end
    SHOES_APP
      # Set up a test handler that responds to a custom builtin
      handler_id = Shoes::DisplayService.subscribe_to_event("builtin", nil) do |cmd_name, args, **kwargs|
        if cmd_name == "ask"
          Shoes::DisplayService.set_builtin_response("test_response")
        end
      end

      # Call shoes_builtin which should now return the response
      app = Shoes.APPS[0]
      result = app.send(:shoes_builtin, "ask", "What?")
      assert_equal "test_response", result

      Shoes::DisplayService.unsub_from_events(handler_id)
    SHOES_SPEC
  end

  def test_unsupported_feature
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC, expect_process_fail: true)
      Shoes.app(features: :html) do
        para "Not supported by Niente, though."
      end
    SHOES_APP
      assert true
    SHOES_SPEC
  end

  def test_unknown_feature
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app(features: :squid) do
        para "No such feature, though."
      end
    SHOES_APP
      assert true
    SHOES_SPEC
  end
end
