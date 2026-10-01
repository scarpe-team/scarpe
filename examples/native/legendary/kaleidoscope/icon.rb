# The Kaleidoscope's store icon: one petal, eight times over, drawn at 256 x 256.
#
#   scarpe peek examples/native/legendary/kaleidoscope/icon.rb --scale 2 --shot icon.png

C = 120 # the middle of the tile

Shoes.app(title: "Kaleidoscope icon", width: 256, height: 256, resizable: false) do
  # Every copy of a path: four turns, and the four turns of its reflection.
  def rosette(points, reflected)
    shape do
      4.times do |k|
        a = k * Math::PI / 2
        points.each_with_index do |(x, y), i|
          y = -y if reflected
          px = C + x * Math.cos(a) - y * Math.sin(a)
          py = C + x * Math.sin(a) + y * Math.cos(a)
          i.zero? ? move_to(px, py) : line_to(px, py)
        end
      end
    end
  end

  def glowing(points, color, partner, width)
    cap :curve
    nofill
    [[width * 2 + 10, 0.1], [width * 2 + 3, 0.24], [width, 1.0]].each do |w, alpha|
      strokewidth w
      stroke rgb(*color, alpha)
      rosette(points, false)
      stroke rgb(*partner, alpha)
      rosette(points, true)
    end
  end

  def curve(n, &point)
    (0..n).map { |i| point.call(i / n.to_f) }
  end

  background ENV.fetch("ICON_BG", "#ffffff")
  stack(left: 8, top: 8, width: 240, height: 240) do
    background "#2a1f5c".."#0a0714", angle: 30
    nostroke
    fill rgb(160, 120, 255, 0.08)
    oval C, C, 216, center: true
    fill "#07050f"
    oval C, C, 196, center: true

    teal, blue, violet, green, cream = [62, 230, 193], [88, 180, 255], [180, 140, 255], [124, 242, 154], [245, 247, 255]
    petal = curve(24) { |t| r = 16 + 72 * t; a = 0.4 * Math.sin(Math::PI * t); [r * Math.cos(a), r * Math.sin(a)] }
    glowing(petal, teal, blue, 3.5)
    bud = curve(16) { |t| r = 8 + 34 * t; a = 0.5 * Math.sin(Math::PI * t); [r * Math.cos(a + 0.78), r * Math.sin(a + 0.78)] }
    glowing(bud, violet, green, 2.5)
    ring = curve(16) { |t| a = 0.14 + 0.5 * t; [74 * Math.cos(a), 74 * Math.sin(a)] }
    glowing(ring, cream, violet, 2)
    loop = curve(20) { |t| a = 2 * Math::PI * t; [58 * 0.92 + 7 * Math.cos(a), 58 * 0.38 + 7 * Math.sin(a)] }
    glowing(loop, blue, teal, 2)
    nostroke
    fill rgb(*cream, 0.25)
    oval C, C, 16, center: true
    fill rgb(*cream)
    oval C, C, 7, center: true

    nofill
    strokewidth 2
    stroke rgb(255, 255, 255, 0.22)
    oval C, C, 196, center: true
    mask do # the tile's rounded corners; a mask shows through what it paints solid
      nostroke
      fill black
      rect 0, 0, 240, 240, curve: 54
    end
  end
end
