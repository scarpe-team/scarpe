# line.move(x, y) moves only the line's start point; its far end stays put.
#
# Expected (Shoes 3): the whole line moves. Shoes 3 draws a line from its place box,
# (ix, iy) to (ix + iw, iy + ih) (s3t_shape.c:127-132), and shoes_shape_move shifts that
# box, so a vertical line stays vertical 200 px to the right.
# Actual (Lacci + native): Line keeps left, top, x2 and y2 as absolute points and move
# sets only left and top, so the line runs diagonally from (220, 20) back to (20, 180).
Shoes.app(width: 300, height: 200) do
  stroke red
  strokewidth 3
  @line = line 20, 20, 20, 180
  @line.move(220, 20)
end
