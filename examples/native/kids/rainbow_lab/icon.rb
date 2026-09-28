# Rainbow Lab's icon: three drops of paint falling into a glass bowl under a rainbow.
# Rendered at 2x from this 256x256 window, once over black and once over white
# (ICON_MATTE or ICON_BACKDROP), so the corners and the shadow can be matted see-through.
#
#   scarpe peek examples/native/kids/rainbow_lab/icon.rb --scale 2 --shot icon.png

RED, YELLOW, BLUE = [229, 57, 53], [255, 204, 51], [47, 128, 237]
PURPLE = [142, 76, 196]

Shoes.app(title: "Rainbow Lab icon", width: 256, height: 256, resizable: false) do
  def paint(color, alpha = 1.0) = rgb(*color, alpha)
  def shade(color, amount) = color.map { |c| (c * (1 - amount)).round }
  def tint(color, amount) = color.map { |c| (c + (255 - c) * amount).round }

  # a drop: a teardrop pointing up, with a shine
  def drop(x, y, size, color)
    s = size
    shape(fill: paint(color), stroke: paint(shade(color, 0.25)), strokewidth: 2.5) do
      move_to x, y - s * 0.62
      curve_to x + s * 0.12, y - s * 0.34, x + s * 0.42, y - s * 0.08, x + s * 0.42, y + s * 0.16
      curve_to x + s * 0.42, y + s * 0.4, x + s * 0.24, y + s * 0.52, x, y + s * 0.52
      curve_to x - s * 0.24, y + s * 0.52, x - s * 0.42, y + s * 0.4, x - s * 0.42, y + s * 0.16
      curve_to x - s * 0.42, y - s * 0.08, x - s * 0.12, y - s * 0.34, x, y - s * 0.62
    end
    nostroke
    oval x - s * 0.16, y + s * 0.06, s * 0.16, s * 0.26, center: true, fill: paint([255, 255, 255], 0.75)
  end

  background ENV["ICON_MATTE"] || ENV["ICON_BACKDROP"] || "#ffffff"
  nostroke
  5.times { |i| rect 25 - i, 28 + i, 206 + i * 2, 206 + i, curve: 46 + i, fill: rgb(40, 20, 60, 0.05) }
  rect 25, 25, 206, 206, curve: 46, fill: paint([255, 247, 234])..paint([236, 224, 255])

  # the rainbow, behind everything
  nofill
  [RED, [255, 138, 30], YELLOW, [67, 178, 88], BLUE, PURPLE].each_with_index do |color, i|
    r = 88 - i * 9
    arc 128 - r, 152 - r, r * 2, r * 2, Math::PI, 2 * Math::PI, stroke: paint(color, 0.85), strokewidth: 9.5
  end

  # the bowl: the bottom half of an oval, glass, with purple paint and a swirl of fresh blue
  bx, by, rx, ry = 128, 156, 72, 62
  level = 0.42 # the angle down the bowl's side where the paint's surface meets it
  sy = by + ry * Math.sin(level)
  half = rx * Math.cos(level)
  nostroke
  arc bx - rx, by - ry, rx * 2, ry * 2, 0, Math::PI, fill: paint([255, 255, 255], 0.6)
  arc bx - rx, by - ry, rx * 2, ry * 2, level, Math::PI - level, fill: paint(tint(PURPLE, 0.05))..paint(shade(PURPLE, 0.22))
  oval bx, sy, half * 2, half * 0.34, center: true, fill: paint(tint(PURPLE, 0.22))
  cap :round
  strokewidth 5
  shape(stroke: paint(BLUE)) { move_to bx - 30, sy + 2; curve_to bx - 18, sy + 9, bx + 22, sy + 8, bx + 28, sy + 1; curve_to bx + 30, sy - 5, bx + 8, sy - 7, bx - 2, sy - 2 }
  nofill
  strokewidth 4
  arc bx - rx, by - ry, rx * 2, ry * 2, 0, Math::PI, stroke: paint([61, 52, 86], 0.28)
  oval bx, by, rx * 2, 24, center: true, stroke: paint([255, 255, 255])
  strokewidth 6
  shape(stroke: paint([255, 255, 255], 0.7)) { move_to bx - 58, by + 16; curve_to bx - 54, by + 36, bx - 42, by + 50, bx - 26, by + 57 }

  # and three drops on their way in
  drop 96, 84, 30, RED
  drop 128, 58, 34, YELLOW
  drop 160, 90, 30, BLUE
end
