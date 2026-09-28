# Repro (Key Splash): text whose stroke is fully transparent is drawn in solid black.
#
# Fading text out means setting its stroke's alpha down to 0. At exactly 0 the native display
# ignores the colour (apply_text_props in native/src/text/rich.rs skips a stroke that
# is_invisible) and the text falls back to the default ink, so the last frame of a fade shows
# the whole word in black. An alpha of 1/255 is invisible, as it should be. Shapes are fine: a
# fill or stroke with alpha 0 is simply not painted.
#
#   bundle exec ruby exe/scarpe peek examples/native/kids/_repros/key_splash_2.rb --wait 0.3 --shot fade.png
#
# expected: only the two right-hand letters show (orange, and orange at half strength);
#           the "C" faded to nothing
# actual:   the first two letters (alpha 0.0 and 0.001, which rounds to 0 of 255) and the
#           faded "C" are solid black
Shoes.app(title: "Repro: transparent text", width: 560, height: 160) do
  background "#dff1ff"
  [0.0, 0.001, 0.004, 0.5].each_with_index do |alpha, i|
    para "B", size: 80, weight: "bold", stroke: rgb(255, 152, 48, alpha), left: 10 + i * 110, top: 20
    para alpha.to_s, size: 12, left: 10 + i * 110, top: 130
  end
  faded = para "C", size: 80, weight: "bold", stroke: rgb(255, 152, 48, 1.0), left: 450, top: 20
  timer(0.1) { faded.style(stroke: rgb(255, 152, 48, 0.0)) } # the end of a fade
end
