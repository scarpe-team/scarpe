# Repro (Night Light): a few small things moving far apart repaint the whole window.
#
# Twelve 8-pixel dots drift across the window, and nothing else changes: well under 1% of
# the window's pixels. Each frame the window should repaint the twelve little places the dots
# left and reached. Instead every frame is repainted in full, because native/src/paint/damage.rs
# merge() turns more than MAX_RECTS (8) separate rects into their one bounding box, which here
# spans the window, and plan() then paints Everything (MOSTLY = 0.5). With DOTS=7 the same
# window repaints only the dots.
#
# Scenes with scattered life (fireflies, twinkling stars, confetti, fish) meet this all the
# time. Grouping the rects into at most 8 clusters (merging the nearest pair until 8 remain)
# would keep them small.
#
#   SCARPE_NATIVE_GHOST=1 SCARPE_NATIVE_STATS=stats SCARPE_NATIVE_ARGS="--exit-after 5" \
#     bundle exec ruby exe/scarpe --native examples/native/kids/_repros/night_light_1.rb
#   then read "counters" in stats/rust.json
#
# expected: repaints_in_part for nearly every frame, each only a few thousand pixels
# actual:   repaints_in_full for nearly every frame. Measured 28 Sep 2026 on an M5, 5 s at 2x:
#           12 dots 149 full, 0 partial, 6.9 ms a paint; 7 dots 1 full, 147 partial, 0.2 ms
DOTS = Integer(ENV.fetch("DOTS", "12"))

Shoes.app(title: "Repro: scattered damage", width: 960, height: 640) do
  background "#141a44".."#46397f"
  nostroke
  dots = Array.new(DOTS) do |i|
    oval 60 + (i * 211) % 840, 60 + (i * 157) % 520, 8, center: true, fill: "#fff4cc"
  end
  animate(30) do |frame|
    dots.each_with_index { |dot, i| dot.style(left: 60 + (i * 211) % 840 + (frame % 60) / 2.0) }
  end
end
