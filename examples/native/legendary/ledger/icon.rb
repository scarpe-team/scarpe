# Ledger's icon: a green tile holding a page with a rising line on it.
#
#   scarpe peek icon.rb --scale 2 --shot icon.png
#
# draws it at 512 x 512. The store's copy has see-through corners: it is drawn once on
# white and once on black (ICON_BACKDROP), and where the two pictures differ is the part
# you can see through.
BACKDROP = ENV.fetch("ICON_BACKDROP", "#ffffff")

Shoes.app(title: "Ledger icon", width: 256, height: 256, resizable: false) do
  background BACKDROP
  nostroke

  # the tile
  fill "#46a27a".."#1d5a41"
  rect 24, 24, 208, 208, curve: 46

  # the page, with a soft shadow under it
  fill rgb(0, 0, 0, 0.2)
  rect 60, 64, 136, 146, curve: 16
  fill "#f7f4ee"
  rect 60, 58, 136, 146, curve: 16

  # two lines of writing
  fill "#dcd3c2"
  rect 80, 80, 64, 8, curve: 4
  rect 80, 96, 40, 8, curve: 4

  # the running balance, rising
  points = [[80, 176], [98, 164], [114, 170], [134, 146], [152, 152], [176, 118]]
  fill gradient(rgb(46, 125, 91, 0.4), rgb(46, 125, 91, 0.04))
  shape do
    move_to 80, 188
    points.each { |x, y| line_to x, y }
    line_to 176, 188
  end
  nofill
  stroke "#2e7d5b"
  strokewidth 6
  cap :curve
  shape do
    move_to(*points.first)
    points.drop(1).each { |x, y| line_to x, y }
  end
  fill "#f7f4ee"
  strokewidth 5
  oval 176, 118, 16, center: true
end
