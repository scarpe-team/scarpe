# Shape Sorter's icon: the wooden box with its friendly face, and a star just
# about to drop into its hole. Rendered at 2x from this 256x256 window, once on
# black and once on white (ICON_BACKDROP, or ICON_MATTE for the store's script),
# so the icon and its shadow lift off cleanly.

INK = "#3b2a22"
STAR = Array.new(10) do |i|
  angle = -Math::PI / 2 + i * Math::PI / 5
  reach = i.even? ? 1.05 : 0.48
  [reach * Math.cos(angle), reach * Math.sin(angle) + 0.06]
end

Shoes.app(title: "Shape Sorter icon", width: 256, height: 256, resizable: false) do
  # A closed shape through `points` with rounded corners, `round` along each edge.
  def rounded(points, round)
    cuts = points.each_with_index.map do |(x, y), i|
      k = round[i % round.size]
      before, after = points[i - 1], points[(i + 1) % points.size]
      [[x + (before[0] - x) * k, y + (before[1] - y) * k], [x, y], [x + (after[0] - x) * k, y + (after[1] - y) * k]]
    end
    shape do
      move_to(*cuts[0][0])
      cuts.each_with_index do |(into, corner, out), i|
        line_to(*into) unless i.zero?
        curve_to(*corner, *corner, *out)
      end
      line_to(*cuts[0][0])
    end
  end

  def star_at(x, y, size)
    rounded(STAR.map { |px, py| [x + px * size / 2, y + py * size / 2] }, [0.2, 0.05])
  end

  # a hole: a pale lip, the dark inside, and the far wall catching a little light
  def hole(x, y, size, &outline)
    nostroke
    fill rgb(255, 246, 222)
    outline.call(x, y + 1.5, size + 6)
    fill "#6b4428"
    outline.call(x, y, size)
    fill "#2f1c10"
    outline.call(x, y + size * 0.08, size * 0.84)
  end

  background ENV["ICON_BACKDROP"] || ENV["ICON_MATTE"] || "white"
  nostroke
  4.times { |i| rect 24 - i, 30 + i * 2, 208 + i * 2, 208 + i, curve: 46 + i, fill: rgb(60, 70, 90, 0.06) }
  rect 24, 24, 208, 208, curve: 46, fill: "#e4f4ff".."#fff0dc"
  rect 24, 160, 208, 72, curve: 46, fill: "#f3c58c".."#e3a364"
  rect 24, 160, 208, 30, fill: "#f3c58c"

  # the box's shadow, its front with a face, and its lid with three holes
  oval 128, 206, 170, 18, center: true, fill: rgb(110, 60, 20, 0.22)
  stroke "#b8692c"
  strokewidth 2
  fill "#f2ac66".."#d7813f"
  rect 50, 138, 156, 66, curve: 12
  stroke "#c98b4e"
  fill "#ffe8bd".."#f6c98a"
  rect 44, 96, 168, 58, curve: 14
  hole(84, 124, 32) { |x, y, size| oval x, y, size * 0.98, center: true }
  hole(128, 124, 36) { |x, y, size| star_at(x, y, size) }
  hole(172, 124, 32) do |x, y, size|
    r = size / 2.0
    rounded([[x - 0.8 * r, y - 0.8 * r], [x + 0.8 * r, y - 0.8 * r], [x + 0.8 * r, y + 0.8 * r], [x - 0.8 * r, y + 0.8 * r]], [0.26])
  end
  fill rgb(255, 120, 130, 0.45)
  oval 94, 186, 16, 8, center: true
  oval 162, 186, 16, 8, center: true
  [110, 146].each do |x|
    oval x, 175, 18, 20, center: true, fill: white, stroke: rgb(120, 60, 30, 0.5), strokewidth: 1
    oval x + 1, 177, 9, 10, center: true, fill: INK
  end
  nofill
  stroke INK
  strokewidth 3
  cap :curve
  shape do
    move_to 118, 191
    curve_to 123, 197, 133, 197, 138, 191
  end

  # the star, just about to go in
  nostroke
  oval 128, 112, 40, 8, center: true, fill: rgb(80, 40, 10, 0.12)
  stroke "#d9822a"
  strokewidth 2.5
  fill "#ffd56b".."#ff9d26"
  star_at(128, 58, 64)
  nostroke
  oval 116, 44, 12, 7, center: true, fill: rgb(255, 255, 255, 0.55)
end
