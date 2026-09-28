# Repro: arc's wedge: true never reaches the renderer.
#
# DESIGN 12 says an arc "fills as a chord (wedge: true fills a pie)", and the Rust
# painter reads a `wedge` prop (native/src/paint/shapes.rs), but Lacci's Arc does not
# declare `wedge` as a style, so it logs
#   Unexpected non-style keyword(s) in Shoes::Arc initialize: [:wedge]
# and drops it.
#
# Expected: the left arc is a quarter pie, filled to the centre (a pizza slice).
# Actual:   both arcs are the same filled chord (the straight edge cuts across).
Shoes.app(title: "Arc wedge", width: 320, height: 180) do
  nostroke
  fill red
  arc 20, 20, 140, 140, 0, Math::PI / 2, wedge: true
  arc 170, 20, 140, 140, 0, Math::PI / 2
end
