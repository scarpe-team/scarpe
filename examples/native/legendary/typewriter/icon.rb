# The Typewriter's icon: a sheet in the machine, a line half typed.
# Rendered at 2x from this 256x256 window, once on black and once on white
# (ICON_BACKDROP), so the icon and its shadow lift off cleanly.

Shoes.app(title: "Typewriter icon", width: 256, height: 256, resizable: false) do
  background ENV.fetch("ICON_BACKDROP", "white")
  nostroke
  4.times { |i| rect 24 - i, 30 + i * 2, 208 + i * 2, 208 + i, curve: 46 + i, fill: rgb(30, 20, 10, 0.06) }
  rect 24, 24, 208, 208, curve: 46, fill: "#4a382d".."#241a14"

  rect 76, 52, 104, 104, fill: "#fffdf6".."#efe8d8" # the paper
  [[88, 70, 70], [88, 86, 62], [88, 102, 44]].each { |x, y, w| rect x, y, w, 5, curve: 2, fill: "#3a3431" }
  rect 88, 118, 22, 5, curve: 2, fill: "#b3342b"

  rect 52, 136, 152, 22, curve: 7, fill: "#505056".."#141416" # the platen and its knobs
  [46, 210].each do |x|
    oval x, 147, 24, center: true, fill: "#eceeeb".."#9ea3a0"
    oval x, 147, 8, center: true, fill: "#5a5e5c"
  end

  fill "#a5cbbb".."#6e9888" # the body, its bottom following the icon's round corners
  shape do
    move_to 38, 160
    line_to 218, 160
    line_to 232, 186
    curve_to 232, 211.4, 211.4, 232, 186, 232
    line_to 70, 232
    curve_to 44.6, 232, 24, 211.4, 24, 186
    line_to 38, 160
  end
  2.times do |row|
    6.times do |i|
      x = 78 + row * 10 + i * 20
      oval x, 184 + row * 22, 16, center: true, fill: "#26252a", stroke: "#dfe2df", strokewidth: 2
    end
  end
end
