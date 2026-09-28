# Paint Puddles' icon: a fat rainbow stroke that ends in a dripping puddle, and a
# star friend watching. Rendered at 2x from this 256x256 window, once on black and
# once on white (ICON_BACKDROP, or ICON_MATTE for the store's script), so the icon
# and its shadow lift off cleanly.

RAINBOW = [
  [255, 107, 107], [255, 159, 67], [254, 202, 87], [102, 204, 122],
  [72, 190, 255], [110, 130, 250], [186, 120, 250], [255, 118, 177],
]
INK = "#3d3450"

Shoes.app(title: "Paint Puddles icon", width: 256, height: 256, resizable: false) do
  def rainbow(at)
    i = at.floor % RAINBOW.size
    a, b = RAINBOW[i], RAINBOW[(i + 1) % RAINBOW.size]
    rgb(*a.zip(b).map { |x, y| (x + (y - x) * (at % 1)).round })
  end

  def face(x, y, size)
    nostroke
    fill rgb(255, 105, 135, 0.4)
    oval x - size * 0.3, y + size * 0.1, size * 0.15, size * 0.09, center: true
    oval x + size * 0.3, y + size * 0.1, size * 0.15, size * 0.09, center: true
    fill INK
    oval x - size * 0.17, y - size * 0.02, size * 0.1, size * 0.125, center: true
    oval x + size * 0.17, y - size * 0.02, size * 0.1, size * 0.125, center: true
    nofill
    stroke INK
    strokewidth size * 0.05
    cap :curve
    shape do
      move_to x - size * 0.13, y + size * 0.1
      curve_to x - size * 0.06, y + size * 0.19, x + size * 0.06, y + size * 0.19, x + size * 0.13, y + size * 0.1
    end
  end

  background ENV["ICON_BACKDROP"] || ENV["ICON_MATTE"] || "white"
  nostroke
  4.times { |i| rect 24 - i, 30 + i * 2, 208 + i * 2, 208 + i, curve: 46 + i, fill: rgb(120, 60, 40, 0.06) }
  rect 24, 24, 208, 208, curve: 46, fill: "#fffaf3".."#ffe3ec"

  # the stroke: many short pieces, each a little further through the rainbow
  cap :curve
  nofill
  strokewidth 30
  points = (0..40).map do |i|
    t = i / 40.0
    [58 + 104 * t, 176 - 110 * Math.sin(Math::PI * t * 0.82)]
  end
  points.each_cons(2).with_index do |(a, b), i|
    stroke rainbow(i * 0.13)
    line(*a, *b)
  end

  # the puddle at its end: rings of colour, a shine, and two drips
  x, y = 170, 158
  nostroke
  [[96, 5.5], [76, 6.2], [56, 7.0], [36, 7.8], [18, 0.4]].each do |size, at|
    oval x, y, size * 1.1, size * 0.9, center: true, fill: rainbow(at)
  end
  fill rainbow(5.5)
  rect x - 30, y + 20, 11, 34, curve: 5.5
  oval x - 24.5, y + 54, 15, 17, center: true
  rect x + 14, y + 26, 11, 20, curve: 5.5
  oval x + 19.5, y + 46, 15, 17, center: true
  oval x - 22, y - 18, 22, 10, center: true, fill: rgb(255, 255, 255, 0.5)

  # a star friend, pleased with it all
  sx, sy, r = 74, 76, 34
  corners = Array.new(10) do |i|
    angle = -Math::PI / 2 + i * Math::PI / 5
    reach = i.even? ? r : r * 0.5
    [sx + reach * Math.cos(angle), sy + reach * Math.sin(angle)]
  end
  stroke "#e59a1c"
  strokewidth 2.5
  fill "#ffe98a".."#ffc02e"
  shape do
    corners.each_with_index do |(cx, cy), i|
      round = i.even? ? 0.2 : 0.08
      before, after = corners[i - 1], corners[(i + 1) % 10]
      into = [cx + (before[0] - cx) * round, cy + (before[1] - cy) * round]
      out = [cx + (after[0] - cx) * round, cy + (after[1] - cy) * round]
      i.zero? ? move_to(*into) : line_to(*into)
      curve_to cx, cy, cx, cy, *out
    end
    line_to(*corners[0].zip(corners[9]).map { |a, b| a + (b - a) * 0.2 })
  end
  face(sx, sy + 5, 44)
end
