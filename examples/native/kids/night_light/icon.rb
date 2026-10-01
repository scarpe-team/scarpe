# Night Light's store icon: the moon asleep over the hills, drawn at 256 x 256.
#
#   scarpe peek examples/native/kids/night_light/icon.rb --scale 2 --shot icon.png
#
# Render it once over black and once over white (ICON_MATTE=black, then white)
# and the rounded corners and the shadow can be worked out as see-through.

Shoes.app(title: "Night Light icon", width: 256, height: 256, resizable: false) do
  background ENV["ICON_MATTE"] || ENV["ICON_BACKDROP"] || "white"
  nostroke
  5.times { |i| rect 25 - i, 28 + i, 206 + i * 2, 206 + i, curve: 46 + i, fill: rgb(20, 16, 50, 0.05) }
  stack(left: 25, top: 25, width: 206, height: 206) do
    background "#161d4c".."#4d3d8c"
    nostroke
    [[30, 34, 1.8], [64, 18, 1.4], [150, 20, 1.6], [178, 58, 1.3], [22, 96, 1.4], [186, 112, 1.8], [118, 14, 1.2]].each do |x, y, d|
      oval x, y, d * 2, center: true, fill: rgb(230, 235, 255, 0.7)
    end
    transform :center
    [[40, 58, 9], [172, 34, 7], [184, 140, 6], [26, 140, 5]].each do |x, y, r|
      star x, y, 5, r, r * 0.45, fill: "#fff4cc"
    end

    # the moon, glowing, fast asleep
    14.times { |i| oval 104, 88, 190 - i * 9, center: true, fill: rgb(255, 232, 170, 0.028) }
    fill "#fff8dc".."#ffd97c"
    oval 104, 88, 112, center: true
    fill rgb(226, 178, 96, 0.22)
    [[130, 116, 22, 16], [74, 62, 15, 12], [140, 58, 11, 8]].each { |x, y, w, h| oval x, y, w, h, center: true }
    fill rgb(255, 128, 128, 0.35)
    oval 70, 98, 20, 12, center: true
    oval 138, 98, 20, 12, center: true
    nofill
    stroke "#6b4a2e"
    strokewidth 4
    cap :curve
    [84, 124].each { |x| shape { move_to x - 9, 84; curve_to x - 4, 92, x + 4, 92, x + 9, 84 } }
    shape { move_to 92, 106; curve_to 99, 116, 109, 116, 116, 106 }

    # the hills, a sheep and two fireflies
    nostroke
    fill "#2c2d64".."#1c1c47"
    shape { move_to 0, 164; curve_to 60, 146, 130, 150, 206, 160; line_to 206, 206; line_to 0, 206 }
    fill "#1b3350".."#10203a"
    shape { move_to 0, 186; curve_to 70, 172, 150, 176, 206, 170; line_to 206, 206; line_to 0, 206 }
    [[46, 156], [168, 150]].each do |x, y|
      [26, 16, 8].each_with_index { |d, i| oval x, y, d, center: true, fill: rgb(214, 255, 120, [0.06, 0.12, 0.5][i]) }
      oval x, y, 4, center: true, fill: "#fbffd8"
    end
    fill "#cfc6ec"
    [[112, 184, 42, 22], [96, 181, 16], [106, 174, 18], [120, 172, 18], [132, 178, 16]].each { |x, y, w, h| oval x, y + 2, w, h || w, center: true }
    fill "#fbf8ff"
    [[112, 182, 40, 20], [96, 180, 15], [106, 173, 17], [120, 171, 17], [132, 177, 15]].each { |x, y, w, h| oval x, y, w, h || w, center: true }
    fill "#71679a"
    oval 142, 180, 16, 17, center: true
    fill "#fbf8ff"
    oval 140, 172, 9, center: true

    mask do # the tile's rounded corners
      nostroke
      fill black
      rect 0, 0, 206, 206, curve: 46
    end
  end
end
