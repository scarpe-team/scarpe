# Repro: a Float art coordinate between 0 and 1 is read as a share of the slot.
#
# Shoes 3 places art with shoes_place_exact, which reads left and top as whole
# pixels (ATTR2(int, attr, left, 0), s3_ruby.c:385-392), so line(10, 10, 0.5, 100)
# ends at x = 0. Native reads any Float in (0, 1] as a fraction of the slot
# (style/dim.rs float_dim, reached through paint/shapes.rs coordinate), so the
# line ends at half the slot's width. An animation that moves a shape through
# the slot's top-left pixel (rain, snow, anything wrapping round an edge) jumps
# across the slot for that frame.
#
# Expected: both lines run from (10, 10) down to the slot's left edge; the red dot
#           sits in the top-left corner.
# Actual:   the blue line ends at x = 150 and the red dot is drawn at (150, 100),
#           the middle of the 300x200 slot.
Shoes.app(title: "Art fractions", width: 300, height: 200) do
  strokewidth 3
  line 10, 10, 0, 100, stroke: green   # whole pixels: ends at the left edge
  line 10, 10, 0.5, 100, stroke: blue  # a hair right of it; drawn at half the width
  nostroke
  oval 0.5, 0.5, 12, center: true, fill: red
end
