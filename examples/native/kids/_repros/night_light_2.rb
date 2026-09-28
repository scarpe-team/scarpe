# Repro (Night Light): changing the colour of one small rotated shape repaints the whole window.
#
# A 12-pixel star is turned 20 degrees once, and then only its colour changes each frame, the
# way a star twinkles. The window should repaint the star's corner of the sky. Instead every
# frame is repainted in full: native/src/paint/damage.rs paint_bounds() returns None for any
# art that is rotated, scaled, skewed or translated, and plan() answers None with Everything,
# even though transformed_box() could bound it. Leave the star unturned (TURN=0) and only the
# star is repainted.
#
# Night Light's thirty stars each had a small random turn, which alone made every frame a full
# repaint; it now draws each star's outline already turned, with no rotate style.
#
#   SCARPE_NATIVE_GHOST=1 SCARPE_NATIVE_STATS=stats SCARPE_NATIVE_ARGS="--exit-after 5" \
#     bundle exec ruby exe/scarpe --native examples/native/kids/_repros/night_light_2.rb
#   then read "counters" in stats/rust.json
#
# expected: repaints_in_part for nearly every frame
# actual:   repaints_in_full for nearly every frame. Measured 28 Sep 2026 on an M5, 5 s at 2x:
#           turned 147 full, 0 partial, 6.7 ms a paint; TURN=0 1 full, 148 partial, 0.1 ms
TURN = Integer(ENV.fetch("TURN", "20"))

Shoes.app(title: "Repro: a rotated star", width: 960, height: 640) do
  background "#141a44".."#46397f"
  nostroke
  transform :center
  twinkler = star 480, 320, 5, 12, 5.4, fill: "#fff4cc"
  twinkler.style(rotate: TURN) unless TURN.zero?
  animate(30) do |frame|
    twinkler.style(fill: rgb(255, 244, 204, (0.55 + 0.45 * Math.sin(frame / 10.0)).round(2)))
  end
end
