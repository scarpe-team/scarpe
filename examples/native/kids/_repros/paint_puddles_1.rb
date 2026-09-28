# Repro (found building Paint Puddles): style(rotate:) reaches the display, but
# style(scale:) is dropped without a word.
#
# Lacci's Drawable#style forwards four draw-context settings to the display
# (fill, stroke, strokewidth, rotate: lacci/lib/shoes/drawable.rb, the
# draw_context_props list). `scale` and `skew` are draw-context settings too
# (DrawContext::SETTINGS), and the native display draws them when a shape is
# made with them, but style(scale:) only sets an instance variable: no
# prop_change is sent and nothing warns.
#
# Expected: the right square doubles in size about its centre, as the left one
#           turns by 45 degrees (or, if scaling after creation is out of scope,
#           a warning like the one the comment in #style promises).
# Actual:   the left square turns; the right one stays 60 by 60.
#           SCARPE_NATIVE_TRACE=1 shows {"props":{"rotate":45}} and nothing for scale.
#
#   scarpe peek examples/native/kids/_repros/paint_puddles_1.rb --shot scale.png
#
# Worked around in Paint Puddles by drawing a stamp again at each size as it
# bounces in (slot.clear { ... }), which is idiomatic Shoes anyway.

Shoes.app(title: "style(scale:) repro", width: 300, height: 160) do
  background white
  nostroke
  fill red
  transform :center
  @turned = rect 40, 50, 60, 60
  @scaled = rect 180, 50, 60, 60
  @turned.style(rotate: 45)   # turns, as expected
  @scaled.style(scale: [2, 2]) # does nothing, silently
end
