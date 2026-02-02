# Turtle Barbwire — ported from Hackety Hack
# Draws a barbwire pattern with random turns
require 'scarpe/turtle'

Turtle.start do
  background yellow
  pencolor brown
  pensize 2
  goto 30, 200
  setheading 180
  1000.times do
    forward 20
    turnleft rand(10)
    backward 10
  end
end
