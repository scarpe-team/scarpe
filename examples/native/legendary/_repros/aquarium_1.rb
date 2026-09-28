# A red bar whose left creeps from -2 px to 3 px, a quarter pixel a frame.
#
# Expected (by eye): it creeps along the left edge. Actual: while left is a Float
# in (0, 1] it is read as a fraction of the slot (DESIGN 6, ledger C1), so for
# four frames it jumps to 75, 150, 225 and 300 px, then back to the edge.
# Negative art coordinates are already plain pixels (ruled 27 Sep 2026);
# anything animated through 0 to 1 still flickers across the window.
#
#   scarpe peek examples/native/legendary/_repros/aquarium_1.rb --wait 1.1 --layout
Shoes.app(width: 300, height: 100) do
  stroke red
  strokewidth 3
  @bar = line 0, 20, 0, 80
  animate(10) do |frame|
    x = -2 + frame * 0.25
    @bar.style(left: x, x2: x)
  end
end
