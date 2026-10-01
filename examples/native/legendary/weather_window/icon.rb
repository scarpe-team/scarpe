# Weather Window's icon: a window of four panes, a different weather in each.
# Rendered at 2x from this 256x256 window, once on black and once on white
# (ICON_BACKDROP), so the icon and its shadow lift off cleanly.

Shoes.app(title: "Weather Window icon", width: 256, height: 256, resizable: false) do
  # One pane: its sky, a hill, and what the weather is doing.
  def pane(x, y, sky, hill)
    stack left: x, top: y, width: 70, height: 70 do
      background gradient(*sky)
      nostroke
      yield
      nostroke
      fill hill
      shape do
        move_to 0, 54
        curve_to 20, 44, 46, 46, 70, 52
        line_to 70, 70
        line_to 0, 70
      end
    end
  end

  background ENV.fetch("ICON_BACKDROP", "white")
  nostroke
  4.times { |i| rect 24 - i, 30 + i * 2, 208 + i * 2, 208 + i, curve: 46 + i, fill: rgb(90, 60, 40, 0.07) }
  rect 24, 24, 208, 208, curve: 46, fill: gradient("#f6eee2", "#e6d6c0")

  # the frame
  rect 50, 46, 156, 156, curve: 10, fill: "#9b6b43"
  rect 54, 50, 148, 148, curve: 8, fill: "#b98552"

  pane(58, 54, ["#79c3f0", "#fdf0c9"], "#7cbd6c") do
    oval 44, 22, 34, center: true, fill: rgb(255, 244, 200, 0.35)
    oval 44, 22, 20, center: true, fill: gradient("#fff6cc", "#ffd166")
  end
  pane(128, 54, ["#76838f", "#b7c1c9"], "#6f8d6f") do
    fill rgb(222, 227, 232)
    [[18, 18, 16], [30, 13, 20], [43, 18, 16]].each { |cx, cy, d| oval cx, cy, d, center: true }
    rect 10, 18, 42, 8, curve: 4
    stroke rgb(235, 242, 248, 0.8)
    strokewidth 1.6
    cap :curve
    [[14, 32], [26, 36], [38, 31], [50, 35], [20, 44], [44, 44]].each { |lx, ly| line lx, ly, lx - 2, ly + 7 }
  end
  pane(58, 124, ["#34406a", "#9aa6c8"], "#eaf0f8") do
    oval 16, 16, 12, center: true, fill: "#f5f2e6"
    fill white
    [[30, 12, 4], [48, 20, 3], [58, 10, 4], [22, 34, 3], [40, 38, 4], [56, 36, 3], [10, 44, 3], [34, 24, 3]].each do |fx, fy, d|
      oval fx, fy, d, center: true
    end
  end
  pane(128, 124, ["#262d3c", "#565e6d"], "#384b3c") do
    fill rgb(84, 90, 104)
    [[18, 16, 18], [32, 11, 22], [46, 16, 18]].each { |cx, cy, d| oval cx, cy, d, center: true }
    rect 9, 16, 46, 10, curve: 5
    stroke white
    strokewidth 2.2
    cap :curve
    nofill
    shape do
      move_to 36, 24
      line_to 28, 38
      line_to 38, 40
      line_to 30, 54
    end
  end

  # the bars between the panes, and the sill
  rect 124, 54, 8, 140, fill: "#a67647"
  rect 58, 120, 140, 8, fill: "#a67647"
  rect 40, 200, 176, 12, curve: 4, fill: "#c49160"
  rect 40, 208, 176, 7, curve: 3, fill: "#9b6b43"
end
