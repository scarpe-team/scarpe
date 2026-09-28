# Balloon Pop's store icon: three balloons over the hill, drawn at 256 x 256.
#
#   scarpe peek examples/native/kids/balloon_pop/icon.rb --scale 2 --shot icon.png
#
# Render it once over black and once over white (ICON_MATTE=black, then white)
# and the rounded corners and the shadow can be worked out as see-through.

Shoes.app(title: "Balloon Pop icon", width: 256, height: 256, resizable: false) do
  # A balloon w wide around (cx, top): round at the top, narrowing to its knot, and its string.
  def balloon(cx, top, w, light, deep)
    h = w * 1.18
    x = cx - w / 2.0
    nofill
    stroke rgb(96, 96, 120, 0.8)
    strokewidth 2.2
    cap :curve
    shape { move_to cx, top + h + 6; curve_to cx + 8, top + h + 30, cx - 8, top + h + 50, cx + 2, top + h + 80 }
    nostroke
    fill light..deep
    shape do
      move_to x + w * 0.5, top
      curve_to x + w * 0.79, top, x + w, top + h * 0.21, x + w, top + h * 0.46
      curve_to x + w, top + h * 0.74, x + w * 0.7, top + h * 0.94, x + w * 0.5, top + h
      curve_to x + w * 0.3, top + h * 0.94, x, top + h * 0.74, x, top + h * 0.46
      curve_to x, top + h * 0.21, x + w * 0.21, top, x + w * 0.5, top
    end
    fill deep
    shape { move_to cx - 6, top + h + 7; line_to cx + 6, top + h + 7; line_to cx, top + h - 3 }
    transform :center
    fill rgb(255, 255, 255, 0.55)
    oval(x + w * 0.3, top + h * 0.24, w * 0.15, h * 0.25, center: true).style(rotate: 30)
    transform :corner
    h
  end

  background ENV["ICON_MATTE"] || ENV["ICON_BACKDROP"] || "white"
  nostroke
  5.times { |i| rect 25 - i, 28 + i, 206 + i * 2, 206 + i, curve: 46 + i, fill: rgb(20, 40, 70, 0.05) }
  stack(left: 25, top: 25, width: 206, height: 206) do
    background "#7fcaf6".."#e6f6ff"
    nostroke
    fill rgb(255, 255, 255, 0.95)
    [[34, 48, 26], [52, 42, 30], [70, 50, 22]].each { |x, y, d| oval x, y, d, center: true }
    rect 26, 48, 50, 12, curve: 6

    balloon 72, 58, 64, "#8cc8ff", "#2f86e8"
    fill rgb(255, 255, 255, 0.88)
    shape { move_to 76, 82; curve_to 58, 84, 58, 110, 76, 112; curve_to 67, 106, 67, 88, 76, 82 }
    balloon 146, 46, 66, "#fff59a", "#f2d50f"
    fill rgb(255, 255, 255, 0.9)
    star 146, 84, 5, 15, 6.6
    balloon 106, 74, 78, "#ff8f8a", "#ec3f45"
    fill rgb(255, 255, 255, 0.9)
    shape do
      move_to 106, 136
      curve_to 86, 122, 90, 106, 106, 114
      curve_to 122, 106, 126, 122, 106, 136
    end

    # confetti from a pop, and the hill
    transform :center
    [[34, 124, "#ffd84d", 30], [176, 118, "#2fb35c", -40], [186, 150, "#8a5ae6", 20], [22, 160, "#fb8a26", -20], [168, 22, "#ec3f45", 50]].each do |x, y, c, r|
      rect(x, y, 10, 6, curve: 1.5, fill: c).style(rotate: r)
    end
    transform :corner
    fill "#74c96d".."#4fae5c"
    shape { move_to 0, 176; curve_to 60, 162, 140, 168, 206, 158; line_to 206, 206; line_to 0, 206 }
    [[30, 188, "#ff8fb8"], [96, 194, "#ffffff"], [160, 184, "#ffd84d"]].each do |x, y, c|
      fill c
      5.times { |p| oval x + Math.cos(-Math::PI / 2 + p * 1.2566) * 5, y + Math.sin(-Math::PI / 2 + p * 1.2566) * 5, 8, center: true }
      fill "#ffcf3f"
      oval x, y, 5, center: true
    end

    mask do # the tile's rounded corners
      nostroke
      fill black
      rect 0, 0, 206, 206, curve: 46
    end
  end
end
