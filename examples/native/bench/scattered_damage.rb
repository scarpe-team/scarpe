# Scattered damage (a bench, from the Night Light lane).
#
# Twelve 8 px dots drift across a 960 x 640 window and nothing else changes, as fireflies,
# twinkling stars and confetti do. Past eight separate changes, paint::damage used to join them
# into one bounding box, which here spans the window, so every frame was painted whole. Since
# 28 Sep 2026 it joins the nearest rects until eight remain.
#
#   SCARPE_NATIVE_GHOST=1 SCARPE_NATIVE_STATS=stats SCARPE_NATIVE_ARGS="--exit-after 5" \
#     bundle exec ruby exe/scarpe --native examples/native/bench/scattered_damage.rb
#   then read "counters" and the paint column of "frames" in stats/rust.json
#
# M5, 28 Sep 2026, a ghost window at 2x for 5 s: before, 150 full repaints and 0 partial,
# 4.5 ms a paint; after, 1 full and 148 partial, 0.45 ms. DOTS=7 was already partial.
DOTS = Integer(ENV.fetch("DOTS", "12"))

Shoes.app(title: "Scattered damage", width: 960, height: 640) do
  background "#141a44".."#46397f"
  nostroke
  dots = Array.new(DOTS) do |i|
    oval 60 + (i * 211) % 840, 60 + (i * 157) % 520, 8, center: true, fill: "#fff4cc"
  end
  animate(30) do |frame|
    dots.each_with_index { |dot, i| dot.style(left: 60 + (i * 211) % 840 + (frame % 60) / 2.0) }
  end
end
