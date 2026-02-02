# frozen_string_literal: true

require_relative "test_helper"
require "scarpe/turtle"

class TestTurtle < NienteTest
  def test_turtle_canvas_widget_creation
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      require 'scarpe/turtle'
      Shoes.app do
        @tc = turtle_canvas
      end
    SHOES_APP
      tc = Shoes::TurtleCanvas
      assert tc < Shoes::Widget, "TurtleCanvas should be a Widget subclass"
    SHOES_SPEC
  end

  def test_turtle_canvas_initial_position
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      require 'scarpe/turtle'
      Shoes.app do
        @tc = turtle_canvas
        $start_x = @tc.getx
        $start_y = @tc.gety
      end
    SHOES_APP
      assert_equal 250, $start_x
      assert_equal 250, $start_y
    SHOES_SPEC
  end

  def test_turtle_forward_updates_position
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      require 'scarpe/turtle'
      Shoes.app do
        @tc = turtle_canvas
        @tc.start_draw  # draw mode — no stepping
        @tc.goto(100, 100)
        @tc.setheading(0)  # heading 0 = north (up), internal = 180°
        @tc.forward(50)
        $pos = @tc.getposition
      end
    SHOES_APP
      # heading 0 = north, forward moves UP (y decreases in screen coords)
      assert_equal 100, $pos[0].round
      assert_equal 50, $pos[1].round
    SHOES_SPEC
  end

  def test_turtle_turnleft
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      require 'scarpe/turtle'
      Shoes.app do
        @tc = turtle_canvas
        @tc.start_draw
        @tc.setheading(0)
        @tc.turnleft(90)
        $heading = @tc.getheading
      end
    SHOES_APP
      assert_equal 90, $heading.round
    SHOES_SPEC
  end

  def test_turtle_penup_pendown
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      require 'scarpe/turtle'
      Shoes.app do
        @tc = turtle_canvas
        @tc.start_draw
        $initially_down = @tc.pendown?
        @tc.penup
        $after_up = @tc.pendown?
        @tc.pendown
        $after_down = @tc.pendown?
      end
    SHOES_APP
      assert_equal true, $initially_down
      assert_equal false, $after_up
      assert_equal true, $after_down
    SHOES_SPEC
  end

  def test_turtle_goto
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      require 'scarpe/turtle'
      Shoes.app do
        @tc = turtle_canvas
        @tc.start_draw
        @tc.goto(42, 99)
        $x = @tc.getx
        $y = @tc.gety
      end
    SHOES_APP
      assert_equal 42, $x
      assert_equal 99, $y
    SHOES_SPEC
  end

  def test_turtle_center
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      require 'scarpe/turtle'
      Shoes.app do
        @tc = turtle_canvas
        @tc.start_draw
        @tc.goto(10, 10)
        @tc.center
        $pos = @tc.getposition
      end
    SHOES_APP
      assert_equal 250, $pos[0]
      assert_equal 250, $pos[1]
    SHOES_SPEC
  end

  def test_turtle_draw_module
    # Test that Turtle module exists and has draw/start methods
    assert_respond_to Turtle, :draw
    assert_respond_to Turtle, :start
  end

  def test_turtle_canvas_constants
    assert_equal 500, Shoes::TurtleCanvas::WIDTH
    assert_equal 500, Shoes::TurtleCanvas::HEIGHT
    assert_equal 4, Shoes::TurtleCanvas::SPEED
  end
end
