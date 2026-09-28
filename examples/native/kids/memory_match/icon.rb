# Memory Match's store icon: a card still face down, and the owl's card turned
# up with its gold star, drawn at 256 x 256. Rendered at 2x (and 4x for
# Finder), once on black and once on white (ICON_BACKDROP), so the icon and
# its shadow lift off cleanly.
#
#   scarpe peek examples/native/kids/memory_match/icon.rb --scale 2 --shot icon.png

INK = [74, 59, 82]

Shoes.app(title: "Memory Match icon", width: 256, height: 256, resizable: false) do
  # The owl from the game, on its 100 x 100 grid, k pixels to a step, centred at (@cx, @cy).
  def gx(x) = @cx + (x - 50) * @k
  def gy(y) = @cy + (y - 50) * @k

  def blob(x, y, w, h, color, line: true)
    line ? stroke(rgb(*INK)) : nostroke
    strokewidth @k * 2.2
    fill rgb(*color)
    oval gx(x), gy(y), w * @k, h * @k, center: true
  end

  def patch(color, *points)
    stroke rgb(*INK)
    strokewidth @k * 2.2
    fill rgb(*color)
    shape do
      move_to gx(points[0][0]), gy(points[0][1])
      points.drop(1).each { |x, y| line_to gx(x), gy(y) }
      line_to gx(points[0][0]), gy(points[0][1])
    end
  end

  def owl
    purple, deep, belly, orange = [160, 128, 218], [118, 90, 178], [238, 231, 252], [255, 166, 72]
    patch(deep, [27, 36], [29, 11], [45, 26])
    patch(deep, [73, 36], [71, 11], [55, 26])
    blob(21, 64, 17, 36, deep)
    blob(79, 64, 17, 36, deep)
    blob(50, 57, 64, 72, purple)
    blob(50, 73, 38, 30, belly, line: false)
    blob(38, 44, 25, 25, [255, 255, 255])
    blob(62, 44, 25, 25, [255, 255, 255])
    [38, 62].each do |x|
      blob(x, 45, 11, 12, INK, line: false)
      blob(x + 2.4, 42.4, 4, 4, [255, 255, 255], line: false)
    end
    patch(orange, [45, 54], [55, 54], [50, 62])
  end

  background ENV.fetch("ICON_BACKDROP", "white")
  nostroke
  4.times { |i| rect 24 - i, 30 + i * 2, 208 + i * 2, 208 + i, curve: 46 + i, fill: rgb(60, 40, 110, 0.06) }
  stack(left: 24, top: 24, width: 208, height: 208) do
    background "#f3e8ff".."#dcefff", curve: 46
  end
  # a card still face down, behind
  rect 46, 50, 104, 116, curve: 16, fill: rgb(60, 40, 90, 0.18)
  rect 42, 44, 104, 116, curve: 16, fill: "#7c6cff".."#5a4ae0"
  nofill
  stroke rgb(255, 255, 255, 0.35)
  strokewidth 2.5
  rect 49, 51, 90, 102, curve: 10
  nostroke
  fill white
  oval 94, 108, 30, 24, center: true
  [[76, 90], [88, 82], [100, 82], [112, 90]].each { |x, y| oval x, y, 12, 14, center: true }
  # the owl's card, turned up and matched
  rect 118, 98, 104, 116, curve: 16, fill: rgb(60, 40, 90, 0.2)
  fill "#fffdf7".."#fff5e6"
  stroke "#ffbe28"
  strokewidth 3.5
  rect 112, 90, 104, 116, curve: 16
  nostroke
  fill rgb(234, 226, 255)
  oval 164, 148, 84, center: true
  @cx, @cy, @k = 164, 152, 0.8
  owl
  transform :center
  fill "#ffbe28"
  stroke "#c98f14"
  strokewidth 1.5
  star(203, 103, 5, 10, 5).style(rotate: 180)
  # a few sparkles
  nostroke
  [[56, 192, "#ff64b0", 7], [206, 60, "#2ec470", 8], [90, 204, "#ffbe28", 6]].each do |x, y, color, r|
    star(x, y, 5, r, r * 0.5, fill: color).style(rotate: 180)
  end
end
