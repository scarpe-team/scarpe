# The Aquarium's store icon: Marlow in his tank, drawn at 256 x 256.
#
#   scarpe peek examples/native/legendary/aquarium/icon.rb --scale 2 --shot icon.png

INK = "#2a211d"

Shoes.app(title: "Aquarium icon", width: 256, height: 256, resizable: false) do
  # The fish from the app, scaled up by k and moved to (ox, oy).
  def outline(k, ox, oy, steps)
    shape do
      steps.each { |command, *xy| send(command, *xy.each_slice(2).flat_map { |x, y| [ox + x * k, oy + y * k] }) }
    end
  end

  background ENV.fetch("ICON_BG", "#ffffff")
  stack(left: 8, top: 8, width: 240, height: 240) do
    background "#a6e7f4".."#15629a"
    nostroke
    [[30, 34], [104, 40], [176, 30]].each do |x, width|
      fill rgb(255, 255, 250, 0.18)..rgb(255, 255, 250, 0)
      shape { move_to x, 0; line_to x + width, 0; line_to x + width + 60, 200; line_to x + 20, 200 }
    end
    fill "#f7e1b2".."#d8b276"
    shape { move_to 0, 200; curve_to 60, 188, 150, 212, 240, 196; line_to 240, 240; line_to 0, 240 }
    [[40, 216, "#f7a6b8"], [120, 224, "#9ad0ec"], [196, 214, "#c5b3e6"], [80, 230, "#ffffff"]].each do |x, y, color|
      fill color
      oval x, y, 12, 8, center: true
    end
    # kelp on both sides
    [[22, ["#2e7d4f", "#4caf64", "#8ed17a"]], [214, ["#3f9a5b", "#6cc26f", "#a6de8a"]]].each do |x, colors|
      7.times do |i|
        fill colors[i * 3 / 7]
        side = i.even? ? 1 : -1
        sway = Math.sin(i * 0.6) * 5
        y = 206 - i * 22
        shape(left: x + sway, top: y) do
          move_to 0, 0
          curve_to side * 4, -16, side * 18, -30, side * 30, -36
          curve_to side * 20, -20, side * 10, -8, 0, 0
        end
      end
    end

    # Marlow, three times life size
    k, ox, oy = 1.9, 30, 60
    stroke INK
    strokewidth 4
    fill "#ff9d42".."#ff6b1f"
    outline(k, ox, oy, [[:move_to, 24, 31], [:curve_to, 16, 22, 8, 13, 4, 15], [:curve_to, 9, 25, 9, 37, 4, 47], [:curve_to, 8, 49, 16, 40, 24, 31]])
    outline(k, ox, oy, [[:move_to, 36, 17], [:curve_to, 40, 5, 56, 3, 64, 15], [:line_to, 36, 17]])
    outline(k, ox, oy, [[:move_to, 44, 45], [:curve_to, 46, 54, 54, 56, 60, 45], [:line_to, 44, 45]])
    body = [[:move_to, 20, 31], [:curve_to, 26, 13, 54, 9, 74, 15], [:curve_to, 86, 19, 92, 27, 90, 32],
      [:curve_to, 88, 39, 74, 48, 52, 48], [:curve_to, 34, 48, 22, 41, 20, 31]]
    outline(k, ox, oy, body)
    strokewidth 3
    fill white
    [[68, 31, 9, 27], [47, 30.5, 12, 32], [29, 31, 7, 18]].each do |x, y, bw, bh|
      oval ox + x * k, oy + y * k, bw * k, bh * k, center: true
    end
    strokewidth 4
    nofill
    outline(k, ox, oy, body)
    nostroke
    fill white
    oval ox + 79 * k, oy + 25 * k, 13 * k, center: true
    fill INK
    oval ox + 80.5 * k, oy + 25.5 * k, 7.8 * k, center: true
    fill white
    oval ox + 82.4 * k, oy + 23.2 * k, 2.8 * k, center: true
    stroke INK
    strokewidth 3
    nofill
    outline(k, ox, oy, [[:move_to, 83, 36], [:curve_to, 85, 38.5, 87, 38.5, 89, 35.5]])

    # bubbles from his mouth
    [[210, 70, 16], [196, 40, 11], [214, 18, 8]].each do |x, y, d|
      stroke rgb(255, 255, 255, 0.85)
      strokewidth 2
      fill rgb(255, 255, 255, 0.18)
      oval x, y, d, center: true
      nostroke
      fill rgb(255, 255, 255, 0.9)
      oval x - d * 0.2, y - d * 0.2, d * 0.3, center: true
    end
    mask do # the tile's rounded corners; a mask shows through what it paints solid
      nostroke
      fill black
      rect 0, 0, 240, 240, curve: 54
    end
  end
end
