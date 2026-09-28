# Kanban's icon: three columns of cards on an indigo tile, one card lifted mid-move.
#
#   scarpe peek icon.rb --scale 2 --shot icon.png
#
# draws it at 512 x 512. The store's copy has see-through corners: it is drawn once on
# white and once on black (ICON_BACKDROP), and where the two pictures differ is the part
# you can see through.
BACKDROP = ENV.fetch("ICON_BACKDROP", "#ffffff")

Shoes.app(title: "Kanban icon", width: 256, height: 256, resizable: false) do
  background BACKDROP
  nostroke

  # the tile
  fill "#7474f7".."#4232c4"
  rect 24, 24, 208, 208, curve: 46

  # three columns
  fill rgb(255, 255, 255, 0.2)
  [50, 106, 162].each { |x| rect x, 54, 44, 150, curve: 11 }

  # the cards in them, some with a coloured label
  fill white
  cards = [[54, 60, 30], [54, 96, 40], [54, 142, 24], [110, 60, 44], [166, 60, 30], [166, 96, 24]]
  cards.each { |x, y, h| rect x, y, 36, h, curve: 6 }
  { [58, 65] => "#e5484d", [58, 101] => "#12a594", [114, 65] => "#d68a00", [170, 65] => "#8e4ec6" }.each do |(x, y), color|
    fill color
    rect x, y, 14, 5, curve: 2.5
  end

  # a card on its way across, with its shadow
  fill rgb(20, 12, 80, 0.25)
  rect 126, 124, 48, 36, curve: 7
  fill white
  rect 122, 116, 48, 36, curve: 7
  fill "#30a46c"
  rect 128, 122, 18, 6, curve: 3
  fill "#c9c6f2"
  rect 128, 134, 34, 5, curve: 2.5
  rect 128, 143, 22, 5, curve: 2.5
end
