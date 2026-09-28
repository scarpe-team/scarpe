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

  # The turtle is Hackety Hack's own PNG, which the native display draws; the SVG data URI it
  # was drew nothing there, so no turtle showed while it stepped (the w9 learner lane).
  def test_the_turtle_is_a_picture_every_display_can_draw
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      require 'scarpe/turtle'
      Shoes.app do
        @tc = turtle_canvas
      end
    SHOES_APP
      turtle = Shoes.APPS.first.all_drawables.grep(Shoes::Image).first
      assert_equal TURTLE_IMAGE, turtle.url
      assert_equal [137, 80, 78, 71], File.binread(turtle.url, 4).bytes, "a PNG"
    SHOES_SPEC
  end

  # Turtle.start's pen swatch sits after its "pen: " label in the flow (ledger C17): given only
  # :top, as Hackety Hack's turtle placed it, native put it over the label.
  def test_the_pen_swatch_sits_in_the_flow_after_its_label
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      require 'scarpe/turtle'
      Turtle.start { forward 10 }
    SHOES_APP
      app = Shoes.APPS.first
      label = app.all_drawables.grep(Shoes::Para).find { |p| p.text == "pen: " }
      swatch = app.document_root.children[app.document_root.children.index(label) + 1]
      assert_kind_of Shoes::Stack, swatch
      assert_nil swatch.style[:top], "placed by the flow, not by :top"
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

  # Hackety Hack's Basic Programming lesson (4.3, "Type it in!") has a child run `Turtle.draw`
  # on its own: an empty canvas, "you won't even see him". With no block, drawing raised.
  def test_turtle_draw_without_a_block_draws_an_empty_canvas
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      require 'scarpe/turtle'
      Turtle.draw
    SHOES_APP
      drawing = Shoes.APPS.first.all_drawables.find { |d| d.is_a?(Shoes::Timer) }
      refute_nil drawing, "draw mode draws from a timer"
      Shoes::DisplayService.dispatch_event("timer", drawing.linkable_id)
      assert Shoes.APPS.first.all_drawables.any? { |d| d.is_a?(Shoes::TurtleCanvas) }
    SHOES_SPEC
  end

  # Stepping through a turtle program shows each command as it comes ("next command:
  # forward"). The name was matched from a backtick in the backtrace, which Ruby 3.4 no
  # longer prints, so the line stayed blank.
  def test_turtle_play_shows_the_next_command
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      require 'scarpe/turtle'
      Shoes.app do
        @tc = turtle_canvas
        $shown = para "start"
        @tc.next_command = $shown
        @tc.toggle_pause
        @tc.speed = 10_000
        @tc.forward(10)
        $after_forward = $shown.text
        @tc.turnright(90)
        $after_turn = $shown.text
      end
    SHOES_APP
      assert_equal "forward", $after_forward
      assert_equal "turnright", $after_turn
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
