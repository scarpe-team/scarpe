# Bubble Garden's store icon: a smiling blossom in the meadow, with soap bubbles
# floating over it. Drawn at 256 x 256 and rendered at 2x, once over black and
# once over white (ICON_BACKDROP), so the tile and its soft shadow lift off cleanly.
#
#   scarpe peek examples/native/kids/bubble_garden/icon.rb --scale 2 --shot icon.png

INK = "#3d2b1f"

Shoes.app(title: "Bubble Garden icon", width: 256, height: 256, resizable: false) do
  def round_outline(cx, cy, w, h = w)
    move_to cx + w / 2.0, cy
    arc_to cx, cy, w, h, 0, 2 * Math::PI
  end

  def bubble(x, y, d)
    stroke rgb(255, 255, 255, 0.9)
    strokewidth 2.5
    fill rgb(255, 255, 255, 0.18)..rgb(255, 255, 255, 0.38)
    oval x, y, d, center: true
    nofill
    strokewidth [d / 12.0, 2.5].max
    [["#ff6ec7", 0.2, 0.9], ["#60d6ff", 0.9, 1.6], ["#ffd65a", 1.6, 2.2]].each do |color, from, to|
      stroke color
      arc x - d * 0.42, y - d * 0.42, d * 0.84, d * 0.84, from, to
    end
    nostroke
    fill rgb(255, 255, 255, 0.95)
    oval x - d * 0.2, y - d * 0.24, d * 0.26, d * 0.16, center: true
    oval x - d * 0.31, y - d * 0.07, d * 0.08, center: true
  end

  background ENV.fetch("ICON_BACKDROP", "white")
  nostroke
  8.times { |i| rect 25 - i * 0.5, 27 + i, 206 + i, 206 + i * 0.5, curve: 46 + i * 0.5, fill: rgb(20, 40, 60, 0.03) }

  stack(left: 24, top: 24, width: 208, height: 208) do
    background "#86cffd".."#fff1d6"
    nostroke
    fill "#aee3a6"
    shape { move_to 0, 150; curve_to 50, 118, 110, 122, 150, 142; curve_to 175, 128, 195, 126, 208, 132; line_to 208, 208; line_to 0, 208 }
    fill "#7fd072"
    shape { move_to 0, 166; curve_to 70, 150, 140, 172, 208, 158; line_to 208, 208; line_to 0, 208 }

    # the stem and its leaves
    stroke "#3f9b3f"
    strokewidth 7
    cap :curve
    line 96, 214, 96, 128
    nostroke
    fill "#86d876".."#3f9b3f"
    shape do
      [[-1, 184], [1, 172]].each do |side, y|
        move_to 96, y
        curve_to 96 + side * 8, y - 16, 96 + side * 24, y - 19, 96 + side * 27, y - 13
        curve_to 96 + side * 19, y + 2, 96 + side * 8, y + 3, 96, y
      end
    end

    # a pink blossom with a face
    cx, cy, r = 96, 112, 36
    fill "#ffd0df".."#ff6f9c"
    shape { 5.times { |i| a = -Math::PI / 2 + i * 2 * Math::PI / 5; round_outline(cx + Math.cos(a) * r * 0.62, cy + Math.sin(a) * r * 0.62, r * 1.02) } }
    fill "#fff3a3".."#ffc93c"
    oval cx, cy, r * 0.98, center: true
    f = r * 0.5
    fill rgb(255, 120, 150, 0.55)
    shape { round_outline(cx - f * 0.72, cy + f * 0.3, f * 0.42, f * 0.26); round_outline(cx + f * 0.72, cy + f * 0.3, f * 0.42, f * 0.26) }
    fill INK
    shape { [-1, 1].each { |side| round_outline(cx + side * f * 0.38, cy - f * 0.08, f * 0.27, f * 0.35) } }
    fill white
    shape { [-1, 1].each { |side| round_outline(cx + side * f * 0.38 - f * 0.05, cy - f * 0.16, f * 0.11) } }
    stroke INK
    strokewidth 2.6
    nofill
    shape { move_to cx - f * 0.3, cy + f * 0.26; curve_to cx - f * 0.12, cy + f * 0.56, cx + f * 0.12, cy + f * 0.56, cx + f * 0.3, cy + f * 0.26 }

    # bubbles drifting up and away
    bubble 150, 58, 70
    bubble 58, 40, 38
    bubble 176, 132, 26

    mask do # the tile's rounded corners
      nostroke
      fill black
      rect 0, 0, 208, 208, curve: 46
    end
  end
end
