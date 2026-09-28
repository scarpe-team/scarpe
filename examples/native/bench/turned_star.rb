# A turned star twinkling (a bench, from the Night Light lane).
#
# A 12 px star is turned 20 degrees once, then only its colour changes each frame. Art with any
# rotate, scale or skew used to have no paint bounds at all, so each change painted the whole
# window. Since 28 Sep 2026 its bounds are its turned box, stretched by what its stroke and
# points reach. TURN=0 leaves the star unturned.
#
#   SCARPE_NATIVE_GHOST=1 SCARPE_NATIVE_STATS=stats SCARPE_NATIVE_ARGS="--exit-after 5" \
#     bundle exec ruby exe/scarpe --native examples/native/bench/turned_star.rb
#   then read "counters" and the paint column of "frames" in stats/rust.json
#
# M5, 28 Sep 2026, a ghost window at 2x for 5 s: before, 150 full repaints and 0 partial,
# 5.6 ms a paint; after, 1 full and 149 partial, 0.12 ms.
TURN = Integer(ENV.fetch("TURN", "20"))

Shoes.app(title: "A turned star", width: 960, height: 640) do
  background "#141a44".."#46397f"
  nostroke
  transform :center
  twinkler = star 480, 320, 5, 12, 5.4, fill: "#fff4cc"
  twinkler.style(rotate: TURN) unless TURN.zero?
  animate(30) do |frame|
    twinkler.style(fill: rgb(255, 244, 204, (0.55 + 0.45 * Math.sin(frame / 10.0)).round(2)))
  end
end
