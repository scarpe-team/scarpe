# Repro: a border takes its stroke width from the pen, where Shoes 3 gives it 1.
#
# Shoes 3 strokes a border with its own `strokewidth` style, 1 unless given
# (shoes_border_draw: `sw = ATTR2(dbl, self_t->attr, strokewidth, 1.)`,
# s3t_pattern.c:219); the canvas's pen (`strokewidth 6` below) is for shapes. Lacci's
# Border `uses_draw_context`, so the pen's width wins over its default of 1, and a
# pill drawn after some thick art gets a thick ring. Weather Window met it: its
# chips' 1 px borders came out 4 px wide after the mug's handle set `strokewidth 4`.
#
# Expected: both boxes have the same hairline red border (1 px).
# Actual:   the left box's border is 6 px wide, the right one (strokewidth: 1 given) is 1 px.
Shoes.app(title: "Border width", width: 320, height: 140) do
  strokewidth 6
  line 20, 120, 300, 120, stroke: gray # the pen is for shapes like this line
  stack left: 20, top: 20, width: 130, height: 70 do
    border red, curve: 12
  end
  stack left: 170, top: 20, width: 130, height: 70 do
    border red, curve: 12, strokewidth: 1
  end
end
