# The Bloop Sequencer's icon: a corner of the grid with the playhead passing.
# Rendered at 2x from this 256x256 window, once on black and once on white
# (ICON_BACKDROP), so the icon and its shadow lift off cleanly.

Shoes.app(title: "Bloop Sequencer icon", width: 256, height: 256, resizable: false) do
  background ENV.fetch("ICON_BACKDROP", "white")
  nostroke
  4.times { |i| rect 24 - i, 30 + i * 2, 208 + i * 2, 208 + i, curve: 46 + i, fill: rgb(20, 10, 40, 0.05) }
  rect 24, 24, 208, 208, curve: 46, fill: "#2a2352".."#17132e"

  colors = [[255, 107, 107], [255, 196, 87], [72, 219, 170], [124, 156, 255]]
  lit = ["x.x.", ".x.x", "xxx.", "x..x"]
  rect 91, 50, 38, 156, curve: 12, fill: rgb(255, 255, 255, 0.1) # the playhead's column
  4.times do |row|
    4.times do |col|
      on = lit[row][col] == "x"
      color = colors[row]
      color = color.map { |part| (part + (255 - part) * 0.45).round } if on && col == 1 # just played
      rect 55 + col * 38, 55 + row * 38, 32, 32, curve: 9, fill: on ? rgb(*color) : rgb(255, 255, 255, 0.08)
    end
  end
end
