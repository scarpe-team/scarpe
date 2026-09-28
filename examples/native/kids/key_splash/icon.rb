# Key Splash's store icon: a big A blooming over the hills, drawn at 256 x 256.
# Rendered at 2x (and 4x for Finder), once on black and once on white
# (ICON_BACKDROP), so the icon and its shadow lift off cleanly.
#
#   scarpe peek examples/native/kids/key_splash/icon.rb --scale 2 --shot icon.png

FONT_FILE = File.join(__dir__, "..", "_fonts", "Fredoka.ttf")

Shoes.app(title: "Key Splash icon", width: 256, height: 256, resizable: false) do
  font FONT_FILE
  background ENV.fetch("ICON_BACKDROP", "white")
  nostroke
  4.times { |i| rect 24 - i, 30 + i * 2, 208 + i * 2, 208 + i, curve: 46 + i, fill: rgb(40, 70, 120, 0.06) }
  stack(left: 24, top: 24, width: 208, height: 208) do
    background "#8fd0ff".."#fff0de", curve: 46
  end
  # the hills, kept inside the rounded corners
  fill "#86dc95".."#4fbd6d"
  shape do
    move_to 24, 190
    curve_to 80, 172, 150, 200, 232, 180
    line_to 232, 186
    curve_to 232, 212, 212, 232, 186, 232
    line_to 70, 232
    curve_to 44, 232, 24, 212, 24, 186
  end
  # three flowers on the hill
  [[58, 200, "#ff64b0"], [196, 196, "#ffbe28"], [150, 214, "#9268fa"]].each do |x, y, color|
    stroke "#3f9d58"
    strokewidth 2
    line x, y, x, y - 12
    nostroke
    fill color
    5.times { |petal| oval x + 5 * Math.cos(petal * 1.2566), y - 14 + 5 * Math.sin(petal * 1.2566), 7, center: true }
    fill "#fff3b0"
    oval x, y - 14, 5, center: true
  end
  # a soft glow, a ring of colour spreading out, and sparks flying
  fill rgb(255, 255, 255, 0.45)
  oval 128, 122, 150, center: true
  nofill
  stroke rgb(255, 94, 98, 0.35)
  strokewidth 3
  oval 128, 122, 176, center: true
  nostroke
  transform :center
  [[52, 70, "#ffbe28", 14], [206, 62, "#4092ff", 12], [210, 150, "#2ec470", 11], [46, 150, "#9268fa", 10],
   [128, 36, "#ff64b0", 9]].each do |x, y, color, r|
    star(x, y, 5, r, r * 0.5, fill: color).style(rotate: 180) # points up
  end
  [[84, 44, "#16b8ac"], [178, 40, "#ff9830"], [226, 106, "#ff5e62"], [34, 108, "#4092ff"]].each do |x, y, color|
    oval x, y, 9, center: true, fill: color
  end
  # the letter: a soft shadow, a white rim and the colour on top
  [["#c43446", 0.35, 5, 7], ["#ffffff", 0.75, -2, -2], ["#ff5e62", 1.0, 0, 0]].each do |color, alpha, dx, dy|
    para "A", font: "Fredoka", weight: "bold", size: 150, align: "center", margin: 0, left: 28 + dx, top: 29 + dy,
      width: 200, stroke: rgb(*[color[1, 2], color[3, 2], color[5, 2]].map { |hex| hex.to_i(16) }, alpha)
  end
end
