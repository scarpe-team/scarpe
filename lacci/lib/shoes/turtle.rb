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

# A tiny 32x32 turtle SVG encoded as a data URI (green triangle pointing up)
TURTLE_DATA_URI = "data:image/svg+xml;base64," + [
  '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">' \
  '<polygon points="16,2 28,28 16,22 4,28" fill="#2a2" stroke="#060" stroke-width="1.5"/>' \
  '</svg>'
].pack("m0")

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
    @image = image TURTLE_DATA_URI
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
    @image = image TURTLE_DATA_URI
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

    method = nil
    bt = caller
    1.upto(4) do |i|
      break unless bt[i]
      m = bt[i][/`([^']*)'/, 1]
      if m.nil? || m =~ /^block /
        break
      else
        method = m
      end
    end
    @next_command.replace(method.to_s)
  end

  def drawing?
    @speed.nil? && !@paused
  end

  def update_pen_info
    return unless @pen_info

    bg_color = @bg_color
    fg_color = @fg_color
    pen_size = @pen_size
    @pen_info.append do
      background bg_color
      line 5, 10, 35, 10, :stroke => fg_color, :strokewidth => pen_size
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
        para "pen: "
        @pen_info = stack :top => 5, :width => 40, :height => 20 do
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
          @canvas.instance_eval(&blk)
          @next_command&.replace("(END)")
        end
      end
    end
  end

  private

  def execute_canvas_code(blk)
    # In Shoes3, shape preserves self context. In Scarpe, shape changes self to App.
    # Evaluate directly on canvas — the Widget itself serves as the drawing container.
    @canvas.instance_eval(&blk)
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
      button "execute", :width => 100 do
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
      button "draw all", :width => 100 do
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
