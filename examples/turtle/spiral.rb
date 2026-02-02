# Spiral — a simple turtle graphics demo
require 'scarpe/turtle'

Turtle.draw do
  background black
  pencolor green
  pensize 1
  goto 250, 250
  setheading 0

  200.times do |i|
    forward i * 2
    turnright 91
  end
end
