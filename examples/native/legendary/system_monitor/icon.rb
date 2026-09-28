# System Monitor's icon: two rings, CPU and memory, around a heartbeat, on a dark tile.
#
#   scarpe peek icon.rb --scale 2 --shot icon.png
#
# draws it at 512 x 512. The store's copy has see-through corners: it is drawn once on
# white and once on black (ICON_BACKDROP), and where the two pictures differ is the part
# you can see through.
BACKDROP = ENV.fetch("ICON_BACKDROP", "#ffffff")

Shoes.app(title: "System Monitor icon", width: 256, height: 256, resizable: false) do
  background BACKDROP
  nostroke

  # the tile, with a faint light edge so it holds its shape on a dark page
  fill "#222b37".."#0b0f14"
  rect 24, 24, 208, 208, curve: 46
  nofill
  stroke rgb(255, 255, 255, 0.12)
  strokewidth 2
  rect 25, 25, 206, 206, curve: 45
  nostroke

  # the rings: a faint track, then the arc that fills clockwise from twelve o'clock
  nofill
  cap :curve
  top = -Math::PI / 2
  [[138, 16, "#4fd1c5", 0.72], [92, 12, "#a78bfa", 0.46]].each do |size, width, color, share|
    strokewidth width
    stroke rgb(255, 255, 255, 0.08)
    oval 128, 128, size, center: true
    stroke color
    arc 128 - size / 2, 128 - size / 2, size, size, top, top + 2 * Math::PI * share
  end

  # a heartbeat through the middle
  stroke "#e6edf3"
  strokewidth 5
  shape do
    move_to 100, 130
    [[112, 130], [119, 116], [128, 146], [137, 122], [143, 130], [156, 130]].each { |x, y| line_to x, y }
  end
end
