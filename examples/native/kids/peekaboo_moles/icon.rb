# Peekaboo Moles' store icon: a mole in a party hat peeking out of its hole, with
# a star it has just won. Drawn at 256 x 256 and rendered at 2x, once over black and
# once over white (ICON_BACKDROP), so the tile and its soft shadow lift off cleanly.
#
#   scarpe peek examples/native/kids/peekaboo_moles/icon.rb --scale 2 --shot icon.png

INK = "#3b2a22"

Shoes.app(title: "Peekaboo Moles icon", width: 256, height: 256, resizable: false) do
  def round_outline(cx, cy, w, h = w)
    move_to cx + w / 2.0, cy
    arc_to cx, cy, w, h, 0, 2 * Math::PI
  end

  def star_outline(cx, cy, outer, inner)
    10.times do |i|
      a = -Math::PI / 2 + i * Math::PI / 5
      r = i.even? ? outer : inner
      i.zero? ? move_to(cx + Math.cos(a) * r, cy + Math.sin(a) * r) : line_to(cx + Math.cos(a) * r, cy + Math.sin(a) * r)
    end
    line_to cx, cy - outer
  end

  background ENV.fetch("ICON_BACKDROP", "white")
  nostroke
  8.times { |i| rect 25 - i * 0.5, 27 + i, 206 + i, 206 + i * 0.5, curve: 46 + i * 0.5, fill: rgb(40, 30, 20, 0.03) }

  stack(left: 24, top: 24, width: 208, height: 208) do
    background "#95d8ff".."#fff0d6"
    nostroke
    fill "#b9e4a8"
    shape { move_to 0, 118; curve_to 60, 92, 130, 96, 208, 112; line_to 208, 208; line_to 0, 208 }
    fill "#8fd47c"
    shape { move_to 0, 134; curve_to 80, 120, 150, 138, 208, 128; line_to 208, 208; line_to 0, 208 }

    # the mound and its hole
    fill "#c08a5c".."#9a6a40"
    oval 104, 190, 230, 80, center: true
    fill "#4a2e1d".."#2e1b10"
    oval 104, 176, 138, 42, center: true

    # the mole, in a window whose bottom is the near lip of the hole
    stack(left: 0, top: 0, width: 208, height: 196) do
      cx, base = 104, 176
      fill "#a57e5f".."#7d5b42"
      oval cx, base - 30, 124, 170, center: true
      fill "#e3c4a2"
      oval cx, base - 50, 90, 70, center: true
      fill rgb(255, 125, 140, 0.55)
      shape { round_outline(cx - 38, base - 46, 19, 12); round_outline(cx + 38, base - 46, 19, 12) }
      fill INK
      shape { [-1, 1].each { |side| round_outline(cx + side * 21, base - 74, 14, 17) } }
      fill white
      shape { [-1, 1].each { |side| round_outline(cx + side * 21 - 3, base - 79, 5.5) } }
      stroke rgb(90, 64, 48, 0.55)
      strokewidth 1.8
      shape do
        [-1, 1].each do |side|
          [[-8, -3], [0, 0], [8, 4]].each do |dy, end_dy|
            move_to cx + side * 18, base - (52 - dy * 0.3)
            line_to cx + side * 52, base - (52 - dy - end_dy)
          end
        end
      end
      nostroke
      fill "#7a2e3b"
      shape { move_to cx - 13, base - 38; curve_to cx - 11, base - 20, cx + 11, base - 20, cx + 13, base - 38; line_to cx - 13, base - 38 }
      fill "#ff8fa3"
      oval cx, base - 27, 12, 7, center: true
      fill "#ffb3c1".."#ff7f98"
      oval cx, base - 55, 34, 24, center: true
      fill rgb(255, 255, 255, 0.7)
      oval cx - 7, base - 60, 10, 6, center: true

      # a party hat
      fill "#ff8fc7".."#b86bff"
      shape { move_to cx - 30, base - 96; line_to cx - 2, base - 158; line_to cx + 28, base - 98 }
      fill "#fff3a3"
      shape { [[-10, -114], [9, -124], [-2, -138], [5, -104]].each { |dx, dy| round_outline(cx + dx, base + dy, 8) } }
      fill "#ffd43b"
      oval cx - 2, base - 158, 18, center: true
    end

    # the front of the mound, over the bottom of the mole, and its paws on the lip
    fill "#d19a68".."#b07a4f"
    shape do
      move_to 173, 176
      arc_to 104, 176, 138, 42, 0, Math::PI
      curve_to 20, 184, 0, 196, 0, 208
      line_to 208, 208
      curve_to 208, 196, 188, 184, 173, 176
    end
    fill "#ffd0cc"
    [[64, 170], [144, 170]].each do |x, y|
      shape { round_outline(x, y, 34, 22); [-9, 0, 9].each { |dx| round_outline(x + dx, y - 9, 9) } }
    end

    # the star it just won
    fill "#ffe066".."#f59f00"
    shape { star_outline(170, 44, 24, 11) }
    fill rgb(255, 255, 255, 0.85)
    oval 164, 38, 6, center: true

    mask do # the tile's rounded corners
      nostroke
      fill black
      rect 0, 0, 208, 208, curve: 46
    end
  end
end
