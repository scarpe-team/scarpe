# The For Noah app icon: the card's lace-up shoe on a cream tile, drawn by Scarpe.
#
# The window is the 1024 px icon canvas, with the tile on macOS's icon grid (824 px, 100 in
# from each edge). A frame is always opaque, so the corners are cut away afterwards:
#
#   scarpe peek examples/native/showcase/shoe_icon.rb --shot shoe.png
#   magick shoe.png \( -size 1024x1024 xc:none -fill white \
#     -draw "roundrectangle 100,100 923,923 185,185" \) -compose DstIn -composite shoe_icon.png
#
# Then the PNG becomes the app's .icns:
#
#   scarpe package examples/native/showcase/for_noah.rb --native --dmg --name "For Noah" \
#     --icon shoe_icon.png

INK = "#2b2320"
CLAY = "#c4604a"
CREAM = "#fbf5ec"
K = 2.9 # the card draws its shoe about 246 px long; here it is about 710

Shoes.app(title: "Shoe icon", width: 1024, height: 1024, resizable: false) do
  # A point of the card's shoe, (dx, dy) from its top left corner, at icon size.
  def pt(dx, dy)
    [@x + dx * K, @y + dy * K]
  end

  # Light fading out from a centre: circles, each smaller than the last.
  def glow(x, y, radius, color)
    nostroke
    fill color
    16.times { |i| oval x, y, radius * 2 * (1 - i / 16.0), center: true }
  end

  def lace
    stroke INK
    strokewidth 5 * K
    yield
    stroke CREAM
    strokewidth 3 * K
    yield
  end

  def upper
    stroke INK
    strokewidth 3 * K
    fill "#dc8a6f".."#c4604a"
    shape do
      move_to(*pt(14, 88))
      curve_to(*pt(4, 70), *pt(4, 44), *pt(18, 32))
      curve_to(*pt(34, 22), *pt(62, 26), *pt(78, 34))
      curve_to(*pt(82, 22), *pt(96, 14), *pt(108, 18))
      curve_to(*pt(112, 30), *pt(116, 40), *pt(126, 46))
      curve_to(*pt(160, 56), *pt(196, 60), *pt(220, 68))
      curve_to(*pt(236, 72), *pt(242, 82), *pt(238, 88))
      line_to(*pt(14, 88))
    end
  end

  def sole
    fill CREAM
    shape do
      move_to(*pt(188, 88))
      curve_to(*pt(188, 74), *pt(202, 63), *pt(220, 68))
      curve_to(*pt(236, 72), *pt(242, 82), *pt(238, 88))
      line_to(*pt(188, 88))
    end
    shape do
      move_to(*pt(10, 86))
      line_to(*pt(236, 86))
      curve_to(*pt(246, 88), *pt(246, 102), *pt(232, 102))
      line_to(*pt(16, 102))
      curve_to(*pt(8, 102), *pt(6, 90), *pt(10, 86))
    end
    stroke CLAY
    strokewidth 2 * K
    line(*pt(18, 94), *pt(230, 94))
  end

  def laces
    cap :curve
    5.times do |i|
      ex, ey = 86 + i * 10, 38 + i * 3.5
      lace { line(*pt(ex, ey), *pt(ex + 9, ey - 10)) }
    end
    stroke INK
    strokewidth 1.5 * K
    fill CREAM
    5.times { |i| oval(*pt(83 + i * 10, 35 + i * 3.5), 6 * K) }
    nofill
    lace { bow(98, 24) }
  end

  def bow(kx, ky)
    shape do
      move_to(*pt(kx, ky))
      curve_to(*pt(kx - 10, ky - 16), *pt(kx - 26, ky - 12), *pt(kx - 22, ky - 2))
      curve_to(*pt(kx - 18, ky + 6), *pt(kx - 8, ky + 4), *pt(kx, ky))
      curve_to(*pt(kx + 10, ky - 16), *pt(kx + 26, ky - 12), *pt(kx + 22, ky - 2))
      curve_to(*pt(kx + 18, ky + 6), *pt(kx + 8, ky + 4), *pt(kx, ky))
    end
    shape do
      move_to(*pt(kx, ky))
      curve_to(*pt(kx - 4, ky + 8), *pt(kx - 12, ky + 12), *pt(kx - 16, ky + 24))
    end
    shape do
      move_to(*pt(kx, ky))
      curve_to(*pt(kx + 4, ky + 8), *pt(kx + 8, ky + 16), *pt(kx + 16, ky + 26))
    end
  end

  # Outside the tile is cut away; this colour only softens the tile's edge.
  background "#f5e9dc"

  nostroke
  fill "#fdf8f1".."#f0dfcf"
  rect 100, 100, 824, 824, curve: 185
  glow 330, 300, 330, rgb(255, 255, 255, 0.05)
  nofill
  stroke rgb(90, 60, 40, 0.10)
  strokewidth 3
  rect 102, 102, 820, 820, curve: 183

  # The shoe, centred on the tile, and its shadow on the ground.
  @x = 512 - 125 * K
  @y = 512 - 62 * K
  nostroke
  fill rgb(90, 60, 40, 0.10)
  oval(*pt(126, 108), 236 * K, 14 * K, center: true)
  upper
  sole
  laces
end
