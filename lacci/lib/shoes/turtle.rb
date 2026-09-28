# frozen_string_literal: true

# Turtle Graphics for Scarpe
#
# A port of Hackety Hack's turtle graphics library to work with Scarpe's
# WebView-based display service. In memory of _why the lucky stiff and
# Noah Gibbs.
#
# Usage:
#   require 'scarpe/turtle'
#   Turtle.draw { forward 100; turnleft 90; forward 100 }
#
# Supports both Turtle.draw (instant) and Turtle.start (step-by-step).

require "thread"

# Hackety Hack's little green turtle (its static/turtle.png), 32x32, beside this file so a
# packaged app carries it. It was an SVG data URI, which the native display cannot draw, so no
# turtle showed while it stepped.
TURTLE_IMAGE = File.join(__dir__, "turtle.png")

class Shoes::TurtleCanvas < Shoes::Widget
  WIDTH = 500
  HEIGHT = 500
  SPEED = 4

  include Math
  DEG = PI / 180.0

  attr_writer :next_command, :pen_info
  attr_accessor :speed
  attr_reader :width, :height

  def initialize
    @width = WIDTH
    @height = HEIGHT
    style :width => @width, :height => @height
    @queue = Queue.new
    @image = image TURTLE_IMAGE
    @image.transform :center
    @speed = SPEED
    @paused = true
    reset
    move_turtle_to_top
  end

  def start_draw
    @paused = false
    @speed = nil
    @image&.hide
  end

  ### user commands ###

  def reset
    clear_internal
    @pendown = true
    @heading = 180 * DEG
    @turtle_angle = 180
    @bg_color = white
    @fg_color = black
    @pen_size = 1
    background_internal @bg_color
    stroke @fg_color
    strokewidth @pen_size
    update_position(@width / 2, @height / 2)
    update_turtle_heading
  end

  def forward(len = 100)
    is_step
    x = len * sin(@heading) + @x
    y = len * cos(@heading) + @y
    if @pendown
      line(@x, @y, x, y)
    end
    update_position(x, y)
  end

  def backward(len = 100)
    forward(-len)
  end

  def turnleft(angle = 90)
    is_step
    @heading += angle * DEG
    @heading %= 2 * PI
    update_turtle_heading
  end

  def turnright(angle = 90)
    turnleft(-angle)
  end

  def setheading(direction = 180)
    is_step
    direction += 180
    direction %= 360
    @heading = direction * DEG
    update_turtle_heading
  end

  def penup
    @pendown = false
  end

  def pendown
    is_step
    @pendown = true
  end

  def pendown?
    @pendown
  end

  def goto(x, y)
    is_step
    update_position(x, y)
  end

  def center
    goto(width / 2, height / 2)
  end

  def setx(x)
    is_step
    update_position(x, @y)
  end

  def sety(y)
    is_step
    update_position(@x, y)
  end

  def getx
    @x
  end

  def gety
    @y
  end

  def getposition
    [@x, @y]
  end

  def getheading
    degs = @heading / DEG
    degs += 180
    degs % 360
  end

  ### color/pen commands ###

  def pencolor(args)
    is_step
    stroke args
    @fg_color = args
    update_pen_info
  end

  def pensize(args)
    is_step
    strokewidth args
    @pen_size = args
    update_pen_info
  end

  # Wrap clear to ensure is_step is called
  alias clear_internal clear
  private :clear_internal

  def clear(*args)
    is_step
    clear_internal(*args)
  end

  # Wrap background to track color and ensure turtle stays on top
  alias background_internal background
  private :background_internal

  def background(args)
    is_step
    background_internal args
    move_turtle_to_top
    @bg_color = args
    update_pen_info
  end

  ## UI commands ##

  def step
    @queue.enq nil
  end

  def toggle_pause
    @paused = !@paused
    if !@paused
      @speed = SPEED if @speed.nil?
      step
    end
    @paused
  end

  private

  def update_position(x, y)
    @x, @y = x, y
    @image&.move(x.round - 16, y.round - 16) unless drawing?
  end

  def update_turtle_heading
    return if drawing?

    angle_in_degrees = @heading / DEG
    diff = (angle_in_degrees - @turtle_angle).round
    @turtle_angle += diff
    @image&.rotate(diff)
  end

  def move_turtle_to_top
    return if drawing?
    return unless @image

    # Recreating the image moves it to the top of the z-order (DOM order).
    old_style = @image.style
    image_styles = {}
    [:left, :top, :width, :height, :rotate].each do |k|
      image_styles[k] = old_style[k.to_s] if old_style.key?(k.to_s)
    end
    @image = image TURTLE_IMAGE
    @image.style(**image_styles) unless image_styles.empty?
    @image.transform :center
  end

  def is_step
    return if drawing?

    display_command
    if @paused
      @queue.deq
    else
      sleep 1.0 / @speed
      @queue.deq if @paused
    end
  end

  def display_command
    return unless @next_command

    # The turtle command the program called is the outermost method on the stack before the
    # program's own block. Read from the frames, not the backtrace's text, which Ruby 3.4
    # changed (it quotes 'Shoes::TurtleCanvas#forward' where it printed `forward').
    method = nil
    Array(caller_locations(2, 4)).each do |frame|
      break if frame.label.nil? || frame.label.start_with?("block ")

      method = frame.base_label
    end
    @next_command.replace(method.to_s)
  end

  def drawing?
    @speed.nil? && !@paused
  end

  def update_pen_info
    return unless @pen_info

    # The block keeps the canvas as self (ledger B1), and the canvas's own drawing calls land
    # in the slot being appended to, as in Hackety Hack's turtle. background is the turtle
    # command here, so the slot's own goes by its other name.
    @pen_info.append do
      background_internal @bg_color
      line 5, 10, 35, 10, :stroke => @fg_color, :strokewidth => @pen_size
    end
  end
end

module Turtle
  def self.draw(opts = {}, &blk)
    opts[:draw] = true
    start(opts, &blk)
  end

  def self.start(opts = {}, &blk)
    w = opts[:width] || Shoes::TurtleCanvas::WIDTH
    h = opts[:height] || Shoes::TurtleCanvas::HEIGHT
    opts[:width] = w + 20
    opts[:height] = h + (opts[:draw] ? 60 : 130)

    is_draw = opts.delete(:draw)
    Shoes.app(**opts) do
      extend Turtle
      @block = blk

      unless is_draw
        # Hackety Hack's turtle placed the swatch with :top => 5 alone, and Shoes 3 kept its x
        # where the flow stood, after the label; native puts it at the slot's left edge, over the
        # label (ledger C17), so it sits in the flow instead, 5 px down.
        para "pen: "
        @pen_info = stack :margin_top => 5, :width => 40, :height => 25 do
          background white
          line 5, 10, 35, 10
        end
      end

      button "save...", :width => 100 do
        filename = ask_save_file
        unless filename.nil?
          filename += ".pdf" unless filename =~ /\.pdf$/
          alert "Save not yet supported (would save to #{filename})"
        end
      end

      stack :height => h + 20 do
        background gray
        stack :top => 10, :left => 10, :width => w, :height => h do
          background white
          @canvas = turtle_canvas
        end
      end

      if is_draw
        draw_all
      else
        draw_controls
        @interactive_thread = Thread.new do
          sleep 0.1
          @canvas.instance_eval(&blk) if blk
          @next_command&.replace("(END)")
        end
      end
    end
  end

  private

  def execute_canvas_code(blk)
    # The turtle program's forward, turnleft and pencolor are the canvas's own methods, so it
    # runs on the canvas, as Hackety Hack's turtle ran it. `Turtle.draw` alone has no program,
    # and draws an empty canvas.
    @canvas.instance_eval(&blk) if blk
  end

  def draw_controls
    flow do
      stack do
        flow do
          para "next command: "
          @next_command = para "start", :font => "monospace"
          @canvas.next_command = @next_command
        end
      end
      # execute and draw all sit at the right of their rows, as in Hackety Hack's turtle
      # (:right => '-0px'), which leaves the window room for both rows of controls
      button "execute", :width => 100, :right => 0 do
        @canvas.step
      end
    end

    flow do
      button "slower", :width => 100 do
        @canvas.speed /= 2 if @canvas.speed && @canvas.speed > 2
      end
      @toggle_pause = button "play", :width => 100 do
        paused = @canvas.toggle_pause
        @toggle_pause.text = paused ? "play" : "pause"
      end
      button "faster", :width => 100 do
        @canvas.speed = (@canvas.speed || Shoes::TurtleCanvas::SPEED) * 2
      end
      button "draw all", :width => 100, :right => 0 do
        @interactive_thread&.kill
        @canvas.reset
        @next_command.replace("(draw all)")
        draw_all
      end
    end
    @canvas.pen_info = @pen_info
  end

  def draw_all
    timer 0.1 do
      @canvas.start_draw
      execute_canvas_code @block
    end
  end
end
