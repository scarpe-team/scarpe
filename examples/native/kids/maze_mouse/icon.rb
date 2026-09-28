# Maze Mouse's icon: the mouse in a hand-drawn maze, with the cheese just ahead.
# Rendered at 2x from this 256x256 window, once over black and once over white
# (ICON_MATTE or ICON_BACKDROP), so the corners and the shadow can be matted see-through.
#
#   scarpe peek examples/native/kids/maze_mouse/icon.rb --scale 2 --shot icon.png

PENCIL = [96, 76, 64]

Shoes.app(title: "Maze Mouse icon", width: 256, height: 256, resizable: false) do
  def paint(color, alpha = 1.0) = rgb(*color, alpha)

  # a wobbly pencil line through some points
  def pencil(*points)
    nofill
    shape(stroke: paint(PENCIL), strokewidth: 8, cap: :round) do
      move_to(*points.first)
      points.drop(1).each { |x, y| line_to x, y }
    end
  end

  background ENV["ICON_MATTE"] || ENV["ICON_BACKDROP"] || "#ffffff"
  nostroke
  5.times { |i| rect 25 - i, 28 + i, 206 + i * 2, 206 + i, curve: 46 + i, fill: rgb(40, 30, 20, 0.05) }
  rect 25, 25, 206, 206, curve: 46, fill: paint([255, 252, 240])..paint([250, 240, 218])
  (49..220).step(24) { |x| rect x, 34, 1.5, 188, fill: paint([120, 170, 220], 0.16) }
  (49..220).step(24) { |y| rect 34, y, 188, 1.5, fill: paint([120, 170, 220], 0.16) }

  # a bit of maze: the mouse starts bottom left, the cheese waits top right
  pencil [48, 110], [48, 48], [126, 49]
  pencil [158, 48], [208, 49], [208, 124]
  pencil [48, 150], [49, 208], [112, 208]
  pencil [150, 208], [208, 207], [208, 160]
  pencil [104, 49], [104, 100]
  pencil [150, 124], [208, 124]

  # the cheese, top right
  shape(fill: paint([255, 214, 90]), stroke: paint([214, 150, 30]), strokewidth: 3) do
    move_to 132, 104; line_to 190, 104; line_to 190, 70; line_to 132, 104
  end
  shape(fill: paint([255, 232, 140]), stroke: paint([214, 150, 30]), strokewidth: 3) do
    move_to 132, 104; line_to 190, 70; line_to 182, 62; line_to 125, 97; line_to 132, 104
  end
  [[172, 94, 9], [183, 84, 5], [158, 99, 5]].each { |x, y, d| oval x, y, d, center: true, fill: paint([232, 172, 46]) }

  # the mouse, bottom left, looking at the cheese
  k = 0.92
  ox, oy = 50, 116
  at = ->(x, y) { [ox + x * k, oy + y * k] }
  fur, pink, ear, edge = [184, 178, 200], [250, 164, 186], [214, 206, 226], paint([112, 102, 132])
  strokewidth 4
  shape(stroke: paint(pink), cap: :round) do
    move_to(*at.(22, 66))
    curve_to(*at.(8, 70), *at.(-4, 58), *at.(2, 44))
    curve_to(*at.(6, 34), *at.(14, 38), *at.(10, 44))
  end
  nostroke
  [[38, 82], [60, 82]].each { |x, y| oval(*at.(x, y), 13 * k, 8 * k, center: true, fill: paint(pink)) }
  oval(*at.(46, 62), 62 * k, 42 * k, center: true, fill: paint(fur), stroke: edge, strokewidth: 2.5)
  oval(*at.(48, 69), 42 * k, 22 * k, center: true, fill: paint([232, 228, 240]))
  oval(*at.(60, 30), 28 * k, center: true, fill: paint(ear), stroke: edge, strokewidth: 2.5)
  oval(*at.(60, 31), 17 * k, center: true, fill: paint(pink))
  oval(*at.(72, 50), 44 * k, 38 * k, center: true, fill: paint(fur), stroke: edge, strokewidth: 2.5)
  oval(*at.(90, 56), 20 * k, 15 * k, center: true, fill: paint(fur))
  oval(*at.(76, 26), 32 * k, center: true, fill: paint(ear), stroke: edge, strokewidth: 2.5)
  oval(*at.(76, 27), 20 * k, center: true, fill: paint(pink))
  oval(*at.(98, 54), 10 * k, 9 * k, center: true, fill: paint([236, 110, 140]))
  oval(*at.(79, 59), 10 * k, 6 * k, center: true, fill: paint(pink, 0.6))
  oval(*at.(82, 46), 8 * k, 10 * k, center: true, fill: paint([61, 52, 86]))
  oval(*at.(83.5, 44), 3 * k, center: true, fill: white)
  strokewidth 1.5
  [48, 56, 64].each { |y| line(*at.(94, 57), *at.(110, y + 2), stroke: paint([122, 112, 140], 0.8)) }
end
