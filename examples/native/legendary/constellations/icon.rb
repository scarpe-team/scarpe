# The Constellations store icon: a few stars joined in gold over the hills, at 256 x 256.
#
#   scarpe peek examples/native/legendary/constellations/icon.rb --scale 2 --shot icon.png

GOLD = [255, 214, 140]

Shoes.app(title: "Constellations icon", width: 256, height: 256, resizable: false) do
  background ENV.fetch("ICON_BG", "#ffffff")
  stack(left: 8, top: 8, width: 240, height: 240) do
    background "#03050f".."#22306e"
    nostroke
    sky = Random.new(7)
    60.times do
      oval sky.rand(6..234), sky.rand(6..200), sky.rand(1.2..2.4), center: true, fill: rgb(225, 232, 255, sky.rand(0.2..0.7))
    end
    fill rgb(170, 185, 255, 0.02)
    24.times { |i| oval 10 + i * 10, 176 - i * 7.5, 44 + 26 * Math.sin(i * 1.3).abs, center: true }

    # a little dipper of our own
    stars = [[46, 150], [82, 126], [118, 132], [148, 100], [186, 88], [200, 132], [160, 146]]
    edges = [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 3]]
    cap :curve
    edges.each do |a, b|
      line(*stars[a], *stars[b], strokewidth: 8, stroke: rgb(*GOLD, 0.16))
      line(*stars[a], *stars[b], strokewidth: 2.4, stroke: rgb(*GOLD, 0.95))
    end
    stars.each_with_index do |(x, y), i|
      size = i == 4 ? 7 : 5
      oval x, y, size * 4, center: true, fill: rgb(210, 220, 255, 0.12)
      oval x, y, size, center: true, fill: white
    end

    # a crescent moon
    fill "#fff1c9"
    shape do
      move_to 196, 20
      curve_to 170, 26, 164, 64, 190, 76
      curve_to 176, 60, 180, 32, 196, 20
    end

    fill "#080e26"
    shape { move_to 0, 206; curve_to 70, 184, 150, 196, 240, 188; line_to 240, 240; line_to 0, 240 }
    fill "#040712"
    shape { move_to 0, 222; curve_to 80, 208, 170, 226, 240, 214; line_to 240, 240; line_to 0, 240 }
    shape { move_to 162, 208; curve_to 162, 190, 200, 190, 200, 208 }
    rect 164, 206, 34, 14
    fill rgb(255, 205, 130, 0.95)
    rect 179, 192, 4, 14
    mask do # the tile's rounded corners; a mask shows through what it paints solid
      nostroke
      fill black
      rect 0, 0, 240, 240, curve: 54
    end
  end
end
