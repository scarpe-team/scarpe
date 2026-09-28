# Weather Window: a small room with a big window, and the weather is up to you.
#
# The postcards at "/" choose a weather, and each weather is a page of its own:
# "/sun", "/rain", "/snow" and "/storm". Keys 1 to 4 change it, and Escape
# goes back to the postcards. The storm's lightning is gentle on purpose: one
# soft flash every few seconds, never a flicker.

WIDTH, HEIGHT = 860, 640
GX, GY, GW, GH = 196, 104, 468, 336 # the glass, where the world outside shows
POND = [190, 298, 88, 15]           # the pond: centre and half its width and height
PUDDLES = [[343, 256, 7, 2], [301, 298, 10, 2.5]] # on the path, when it rains
CHIMNEY = [372, 168]                # where the smoke comes out
INK = "#3d2f25"
MUTED = "#8d7b6a"
WOOD = "#9b6b43"
CLEAR = [0, 0, 0, 0]

WEATHERS = {
  "sun" => {
    name: "Sun", key: "1", mood: "Sun. Windows open, washing out.",
    blurb: "Warm, bright, a little breeze.",
    sky: ["#79c3f0", "#fdf0c9"], far: "#a3d49c", near: "#7cbd6c", meadow: ["#69ad5c", "#4f9446"],
    water: ["#7cc5ea", "#4f9cc9"], walls: "#f6e7c8", roof: "#d0643f", lamp: nil, leaves: ["#4d8a4a", "#3f7640"], path: "#e0cfa8",
  },
  "rain" => {
    name: "Rain", key: "2", mood: "Rain. The kettle is on.",
    blurb: "Soft and steady, all afternoon.",
    sky: ["#76838f", "#b7c1c9"], far: "#8ea291", near: "#6f8d6f", meadow: ["#5f805d", "#4b6b4b"],
    water: ["#80949f", "#5b707d"], walls: "#e9dcc3", roof: "#a95a3f", lamp: "#ffd98a", leaves: ["#557b56", "#46694a"], path: "#b9a98c",
  },
  "snow" => {
    name: "Snow", key: "3", mood: "Snow. Nobody is going anywhere.",
    blurb: "Quiet, blue, falling slowly.",
    sky: ["#34406a", "#9aa6c8"], far: "#d9e1ee", near: "#eaf0f8", meadow: ["#f5f8fc", "#dfe7f2"],
    water: ["#cfe1ee", "#a9c3d8"], walls: "#e5d8c0", roof: "#f4f7fb", lamp: "#ffcf73", leaves: ["#7f9a86", "#6a8573"], path: "#d8d6d8",
  },
  "storm" => {
    name: "Storm", key: "4", mood: "Storm. Count the seconds after the flash.",
    blurb: "Wind, rain, a far-off flash.",
    sky: ["#262d3c", "#565e6d"], far: "#445649", near: "#384b3c", meadow: ["#334639", "#28372d"],
    water: ["#4a5c69", "#34444f"], walls: "#cbbfa8", roof: "#7e4430", lamp: "#ffc766", leaves: ["#39503f", "#2f4435"], path: "#8d8472",
  },
}

Drop = Struct.new(:x, :y, :speed, :length, :floor, :line)
Flake = Struct.new(:x, :y, :speed, :sway, :phase, :dot)

Shoes.app(title: "Weather Window", width: WIDTH, height: HEIGHT, resizable: false) do
  url "/", :postcards
  WEATHERS.each_key { |name| url "/#{name}", name.to_sym }

  # ---- a few drawing helpers ----

  def clear_paint
    rgb(*CLEAR)
  end

  # A fluffy cloud: a few round puffs on a flat bottom, in a slot of its own so
  # it can drift as one. The slot stays in the corner and is displaced to where
  # the cloud is, since a slot's own negative left counts from the far edge.
  def cloud(x, y, size, color)
    puffs = stack(left: 0, top: 0, width: (150 * size).round, height: (70 * size).round) do
      nostroke
      fill color
      [[34, 44, 44], [62, 32, 58], [96, 40, 46], [118, 50, 32]].each do |cx, cy, d|
        oval cx * size, cy * size, d * size, center: true
      end
      rect 20 * size, 44 * size, 104 * size, 18 * size, curve: 9 * size
    end
    puffs.style(displace_left: x, displace_top: y)
    puffs
  end

  # A leaf from its stem to its tip, bulging by `width` on both sides.
  def leaf(bx, by, tx, ty, width)
    length = Math.hypot(tx - bx, ty - by)
    nx = -(ty - by) / length * width
    ny = (tx - bx) / length * width
    shape do
      move_to bx, by
      curve_to bx + (tx - bx) * 0.3 + nx, by + (ty - by) * 0.3 + ny, bx + (tx - bx) * 0.8 + nx * 0.6, by + (ty - by) * 0.8 + ny * 0.6, tx, ty
      curve_to bx + (tx - bx) * 0.8 - nx * 0.6, by + (ty - by) * 0.8 - ny * 0.6, bx + (tx - bx) * 0.3 - nx, by + (ty - by) * 0.3 - ny, bx, by
    end
  end

  # Light spreading from a point: rings, each smaller and adding to the last.
  def glow(x, y, size, color, rings = 6)
    nostroke
    fill color
    rings.times { |i| oval x, y, size * (1 - i / rings.to_f), center: true }
  end

  # ---- the world outside ----

  def landscape(w)
    nostroke
    fill w[:far]
    shape do
      move_to 0, 214
      curve_to 60, 188, 110, 176, 170, 188
      curve_to 230, 200, 270, 186, 330, 176
      curve_to 390, 166, 430, 180, GW, 190
      line_to GW, GH
      line_to 0, GH
    end
    fill w[:near]
    shape do
      move_to 0, 236
      curve_to 60, 214, 150, 212, 250, 252
      line_to 250, GH
      line_to 0, GH
    end
    shape do
      move_to 190, 264
      curve_to 270, 230, 360, 212, GW, 226
      line_to GW, GH
      line_to 190, GH
    end
    fill gradient(*w[:meadow])
    shape do
      move_to 0, 272
      curve_to 120, 258, 300, 262, GW, 272
      line_to GW, GH
      line_to 0, GH
    end
  end

  def house(w)
    nostroke
    fill rgb(0, 0, 0, 0.12)
    oval 352, 240, 90, 8, center: true
    fill w[:walls]
    rect 320, 196, 64, 44
    fill "#8a5a3c"
    rect CHIMNEY[0] - 5, CHIMNEY[1], 10, 22
    fill w[:roof]
    shape do
      move_to 312, 200
      line_to 352, 164
      line_to 392, 200
    end
    if w[:name] == "Snow" # a snowy roof still shows its edge
      fill "#b58a6a"
      rect 312, 199, 80, 3
    end
    lit = w[:lamp]
    fill lit || "#a8d4ee"
    rect 328, 208, 12, 12, curve: 2
    rect 364, 208, 12, 12, curve: 2
    if lit
      glow 334, 214, 26, rgb(255, 214, 130, 0.07), 4
      glow 370, 214, 26, rgb(255, 214, 130, 0.07), 4
    end
    fill "#6f4a33"
    rect 346, 220, 12, 20, curve: 2
  end

  # The tree's canopy is kept, so the storm can bend it.
  def tree(w)
    nostroke
    fill rgb(0, 0, 0, 0.12)
    oval 96, 238, 60, 7, center: true
    fill "#6d4c35"
    rect 91, 192, 10, 46, curve: 3
    greens = w[:leaves]
    @canopy = [[96, 176, 70, 0], [74, 186, 44, 1], [118, 186, 44, 1], [84, 160, 44, 0], [110, 158, 42, 1], [96, 146, 34, 0]].map do |x, y, d, shade|
      [oval(x, y, d, center: true, fill: greens[shade]), x, y]
    end
    return unless w[:name] == "Snow"

    fill "#f4f7fb"
    [[84, 142, 30], [110, 141, 28], [96, 133, 22], [66, 170, 24], [126, 171, 22], [96, 158, 26]].each do |x, y, d|
      @canopy << [oval(x, y, d, d * 0.4, center: true), x, y]
    end
  end

  def pond(w)
    x, y, a, b = POND
    nostroke
    fill gradient(*w[:water])
    oval x, y, a * 2, b * 2, center: true
    fill rgb(255, 255, 255, w[:name] == "Snow" ? 0.55 : 0.18)
    oval x - 20, y - 5, a * 0.9, 3, center: true
    fill w[:path]
    shape do # the path from the door, past the pond, down to us
      move_to 346, 240
      curve_to 340, 262, 300, 270, 290, 290
      curve_to 282, 306, 310, 322, 300, GH
      line_to 330, GH
      curve_to 342, 318, 312, 306, 318, 290
      curve_to 326, 272, 360, 262, 358, 240
    end
    return unless %w[Rain Storm].include?(w[:name]) # puddles only when it rains

    fill gradient(*w[:water])
    PUDDLES.each { |px, py, a, b| oval px, py, a * 2, b * 2, center: true }
  end

  def snowman
    nostroke
    fill rgb(40, 60, 100, 0.12)
    oval 116, 318, 52, 8, center: true
    fill "#fbfdff"
    oval 116, 302, 34, center: true
    oval 116, 280, 25, center: true
    oval 116, 263, 18, center: true
    fill "#2d2d33"
    oval 112, 261, 3, center: true
    oval 120, 261, 3, center: true
    [276, 283, 290].each { |y| oval 116, y, 3, center: true }
    fill "#f08a3c"
    shape do
      move_to 116, 264
      line_to 127, 266
      line_to 116, 267
    end
    fill "#c8423a"
    rect 106, 270, 20, 4, curve: 2
    rect 120, 272, 4, 10, curve: 2
    stroke "#6d4c35"
    strokewidth 2
    cap :curve
    line 104, 278, 90, 268
    line 128, 278, 142, 270
  end

  # ---- the weather ----

  def sun_in_the_sky
    glow 380, 70, 150, rgb(255, 244, 200, 0.07), 7
    nostroke
    oval 380, 70, 48, center: true, fill: gradient("#fff6cc", "#ffd166")
    cap :curve
    @rays = (0...12).map { line(0, 0, 0, 0, stroke: rgb(255, 232, 160, 0.85), strokewidth: 3) }
    turn_rays(0)
  end

  def turn_rays(angle)
    @rays.each_with_index do |ray, i|
      a = angle + i * Math::PI / 6
      long = i.even? ? 50 : 42
      ray.style(left: (380 + 32 * Math.cos(a)).round(1), top: (70 + 32 * Math.sin(a)).round(1),
        x2: (380 + long * Math.cos(a)).round(1), y2: (70 + long * Math.sin(a)).round(1))
    end
  end

  def moon
    glow 86, 64, 120, rgb(230, 236, 255, 0.05), 6
    nostroke
    oval 86, 64, 34, center: true, fill: "#f5f2e6"
    fill rgb(190, 196, 214, 0.35)
    oval 80, 60, 8, center: true
    oval 92, 70, 5, center: true
  end

  def start_rain(count, wind, speed, color)
    @wind = wind
    cap :curve
    @drops = Array.new(count) do
      drop = Drop.new(rand(-60.0..GW), rand(-GH.to_f..GH), speed * rand(0.85..1.15), rand(12.0..22.0), rand(210.0..GH + 10))
      drop.line = line(0, 0, 0, 0, stroke: color, strokewidth: 1.3)
      drop
    end
    @ripples = Array.new(24) { oval(0, 0, 4, 2, center: true, fill: clear_paint, stroke: clear_paint, strokewidth: 1) }
    @ripple_ages = Array.new(24, 99)
    @ripple_reach = Array.new(24, 29)
    @next_ripple = 0
  end

  def fall_rain(seconds)
    @drops.each do |drop|
      drop.y += drop.speed * seconds
      drop.x += drop.speed * @wind * seconds
      if drop.y > drop.floor
        splash(drop.x, drop.floor)
        drop.x = rand(-80.0..GW)
        drop.y = rand(-40.0..-10.0)
        drop.floor = rand(210.0..GH + 10)
      end
      drop.line.style(left: drop.x, top: drop.y, x2: drop.x - @wind * drop.length, y2: drop.y - drop.length)
    end
    spread_ripples
  end

  # The pond or puddle a drop landing at (x, y) falls in, if any.
  def water_at(x, y)
    [POND, *PUDDLES].find { |px, py, a, b| ((x - px) / a)**2 + ((y - py) / b)**2 < 0.8 }
  end

  # A ring spreads where a drop lands in water, as wide as the water allows.
  def splash(x, y)
    water = water_at(x, y) or return

    ring = @next_ripple
    @next_ripple = (@next_ripple + 1) % @ripples.size
    @ripple_ages[ring] = 0
    @ripple_reach[ring] = water == POND ? 29 : water[2] * 1.4
    @ripples[ring].style(left: x.round(1), top: y.round(1))
  end

  def spread_ripples
    @ripples.each_with_index do |ring, i|
      age = @ripple_ages[i]
      next if age > 18

      @ripple_ages[i] = age + 1
      size = 4 + age * (@ripple_reach[i] - 4) / 18.0
      fade = age == 18 ? 0 : 0.55 * (1 - age / 18.0)
      ring.style(width: size.round(1), height: (size * 0.32).round(1), stroke: rgb(235, 242, 248, fade))
    end
  end

  def start_snow
    @flakes = Array.new(120) do |i|
      size, speed, alpha = [[2, 16, 0.6], [3, 28, 0.8], [5, 44, 0.95]][i % 3]
      dot = oval(0, 0, size, center: true, fill: rgb(255, 255, 255, alpha))
      Flake.new(rand(0.0..GW), rand(0.0..GH), speed * rand(0.8..1.2), rand(4.0..12.0), rand(0.0..6.28), dot)
    end
  end

  def fall_snow(seconds, time)
    @flakes.each do |flake|
      flake.y += flake.speed * seconds
      flake.x += 6 * seconds # a faint breeze from the left
      if flake.y > GH + 4
        flake.y = -4.0
        flake.x = rand(-20.0..GW)
      end
      x = flake.x + Math.sin(time * 0.9 + flake.phase) * flake.sway
      flake.dot.style(left: x, top: flake.y)
    end
  end

  def start_smoke
    nostroke
    @smoke = Array.new(7) { oval(CHIMNEY[0], CHIMNEY[1], 6, center: true, fill: clear_paint) }
  end

  def puff(frame)
    @smoke.each_with_index do |puff, i|
      age = (frame + i * 14) % 98
      x = CHIMNEY[0] + age * 0.35 + Math.sin(age * 0.08 + i) * 3
      y = CHIMNEY[1] - 2 - age * 0.62
      size = 6 + age * 0.16
      puff.style(left: x.round(1), top: y.round(1), width: size.round(1), height: size.round(1),
        fill: rgb(236, 238, 244, 0.42 * (1 - age / 98.0)))
    end
  end

  # Birds glide across a sunny sky, flapping now and then.
  def start_birds
    stroke "#3b4a5a"
    strokewidth 2
    cap :curve
    @birds = [[-30, 58, 22, 0.0], [-80, 84, 17, 1.7], [-150, 44, 15, 3.1]].map do |x, y, speed, phase|
      { x: x.to_f, y: y, speed: speed, phase: phase, wings: [line(0, 0, 0, 0), line(0, 0, 0, 0)] }
    end
  end

  def fly_birds(seconds, time)
    @birds.each do |bird|
      bird[:x] += bird[:speed] * seconds
      bird[:x] = -40.0 if bird[:x] > GW + 40
      flap = Math.sin(time * 7 + bird[:phase])
      flap = 0.35 if Math.sin(time * 0.8 + bird[:phase]) > 0.3 # gliding
      x = bird[:x]
      y = bird[:y] + Math.sin(time * 0.9 + bird[:phase]) * 4
      tip = y - 5 * flap
      left, right = bird[:wings]
      left.style(left: x - 9, top: tip, x2: x, y2: y)
      right.style(left: x, top: y, x2: x + 9, y2: tip)
    end
  end

  # Little four-pointed glints come and go on the pond.
  def start_glints
    nostroke
    @glints = Array.new(5) { star(0, 0, 4, 6, 1.5, fill: rgb(255, 255, 255, 0)) }
  end

  def twinkle(frame)
    @glints.each_with_index do |glint, i|
      age = (frame + i * 17) % 85
      if age.zero?
        px, py, a, b = POND
        angle = rand * 2 * Math::PI
        glint.style(left: (px + a * 0.7 * rand * Math.cos(angle)).round, top: (py + b * 0.6 * rand * Math.sin(angle)).round)
      end
      glint.fill = rgb(255, 255, 255, [0, Math.sin(age / 20.0 * Math::PI)].max * 0.9) if age <= 21
    end
  end

  def sway_tree(time)
    @canopy.each do |puff, x, y|
      reach = (200 - y) / 60.0 # the top bends most
      bend = (Math.sin(time * 1.6) * 5 + Math.sin(time * 3.1) * 1.8) * reach
      puff.style(left: (x + bend).round(1), top: (y + bend.abs * 0.12).round(1))
    end
  end

  # One strike, far off beyond the tree and the pond: a bolt that fades, and a
  # soft brightening of the sky. The flash takes a tenth of a second to rise and
  # almost a second to fade.
  def strike
    x = rand(50.0..190.0)
    y = -6.0
    points = [[x, y]]
    while y < 160
      y += rand(18.0..28.0)
      x += rand(-18.0..18.0)
      points << [x.round(1), [y, 176].min.round(1)]
    end
    nofill
    cap :curve
    @bolt = [[8, rgb(200, 196, 255, 0.35)], [2.6, rgb(255, 255, 255)]].map do |width, color|
      strokewidth width
      stroke color
      shape do
        move_to(*points.first)
        points.drop(1).each { |px, py| line_to px, py }
      end
    end
    @struck = 0
  end

  def flash
    return unless @struck

    @struck += 1
    f = @struck
    brightness = f <= 3 ? 0.1 * f : 0.3 * (1 - (f - 3) / 26.0)
    @flash.fill = rgb(225, 228, 255, [brightness, 0].max)
    fade = f < 4 ? 1.0 : [1 - (f - 4) / 7.0, 0].max
    @bolt[0].stroke = rgb(200, 196, 255, 0.35 * fade)
    @bolt[1].stroke = rgb(255, 255, 255, fade)
    return if f < 30

    @bolt.each(&:remove)
    @struck = nil
  end

  # ---- the room ----

  def wall
    background "#f2e9dc".."#e2d3bf"
    nostroke
    fill rgb(120, 90, 60, 0.035)
    (0..WIDTH).step(28) { |x| rect x, 0, 12, HEIGHT } # faint stripes on the paper
  end

  def window_frame(w)
    nostroke
    fill rgb(70, 45, 25, 0.12) # its shadow on the wall
    rect GX - 22, GY - 14, GW + 44, GH + 36, curve: 10
    fill WOOD
    rect GX - 18, GY - 18, GW + 36, GH + 36, curve: 8
    fill "#b98552"
    rect GX - 14, GY - 14, GW + 28, GH + 28, curve: 6
    fill "#7a5232"
    rect GX - 3, GY - 3, GW + 6, GH + 6, curve: 3
  end

  # Glass, bars and reflections go on top of the world outside.
  def glazing(w)
    nostroke
    fill gradient(rgb(255, 255, 255, 0.10), rgb(255, 255, 255, 0), angle: 60)
    shape do
      move_to GX, GY
      line_to GX + 150, GY
      line_to GX + 40, GY + GH
      line_to GX, GY + GH
    end
    if w[:name] == "Snow"
      [GX, GX + GW / 2 + 5].each do |x|
        rect x, GY + GH - 38, GW / 2 - 5, 38, fill: gradient(rgb(255, 255, 255, 0), rgb(255, 255, 255, 0.45))
        rect x, GY + 120, GW / 2 - 5, 26, fill: gradient(rgb(255, 255, 255, 0), rgb(255, 255, 255, 0.3))
      end
    end
    fill "#a67647"
    rect GX + GW / 2 - 5, GY, 10, GH
    rect GX, GY + 140, GW, 10
    fill rgb(255, 255, 255, 0.18)
    rect GX + GW / 2 - 5, GY, 2, GH
    rect GX, GY + 140, GW, 2
  end

  def curtains
    nostroke
    fill "#8a6a4f"
    rect 112, 64, 636, 6, curve: 3
    oval 112, 67, 14, center: true
    oval 748, 67, 14, center: true
    [[126, 1], [734, -1]].each do |edge, side|
      fill gradient("#d49a88", "#b8786a", angle: 90 * side)
      shape do
        move_to edge, 70
        line_to edge + side * 92, 70
        curve_to edge + side * 70, 180, edge + side * 40, 250, edge + side * 34, 296
        curve_to edge + side * 44, 360, edge + side * 70, 420, edge + side * 58, 478
        line_to edge, 478
      end
      fill rgb(90, 40, 30, 0.12)
      [24, 48].each { |fold| rect edge + side * fold - (side < 0 ? 4 : 0), 76, 4, 200 }
      fill "#e8c9a0"
      rect(side > 0 ? edge : edge - 44, 292, 44, 9, curve: 4)
    end
  end

  def sill
    nostroke
    fill rgb(70, 45, 25, 0.14)
    rect 144, 488, 572, 10, curve: 5
    fill "#c49160"
    rect 150, 456, 560, 18, curve: 3
    fill "#9b6b43"
    rect 150, 472, 560, 16, curve: 3
  end

  def plant
    nostroke
    fill rgb(70, 45, 25, 0.15)
    oval 230, 468, 46, 6, center: true
    [[230, 432, 196, 392, 7], [230, 432, 212, 380, 8], [232, 430, 236, 372, 8], [234, 432, 258, 380, 8],
     [236, 434, 270, 398, 7], [226, 434, 200, 414, 6], [238, 434, 262, 414, 6]].each_with_index do |(bx, by, tx, ty, width), i|
      fill i.even? ? gradient("#7fbf6a", "#3f7a3a") : gradient("#6cae5c", "#35693a")
      leaf bx, by, tx, ty, width
    end
    fill gradient("#d8845c", "#b0603e")
    shape do
      move_to 212, 434
      line_to 248, 434
      line_to 244, 466
      line_to 216, 466
    end
    fill "#c9704b"
    rect 209, 430, 42, 7, curve: 3
  end

  def mug
    nostroke
    fill rgb(70, 45, 25, 0.15)
    oval 632, 468, 40, 6, center: true
    stroke "#e9e2d6"
    strokewidth 4
    nofill
    oval 648, 450, 14, center: true
    nostroke
    fill gradient("#f7f2ea", "#ddd3c4", angle: 90)
    rect 614, 434, 30, 32, curve: 5
    fill "#6fa3b6"
    rect 614, 444, 30, 5
    fill "#7a4a2c"
    oval 629, 436, 24, 5, center: true
    @steam = Array.new(9) { oval(629, 430, 8, center: true, fill: clear_paint) }
  end

  # Steam: soft puffs that rise, curl, grow and thin out, one after another.
  def rise_steam(frame)
    @steam.each_with_index do |wisp, i|
      age = (frame + i * 10) % 90
      x = 629 + Math.sin(age * 0.07 + i * 0.9) * (2 + age * 0.06)
      size = 7 + age * 0.14
      wisp.style(left: x.round(1), top: (432 - age * 0.6).round(1), width: size.round(1), height: (size * 1.3).round(1),
        fill: rgb(255, 255, 255, 0.2 * Math.sin(age / 90.0 * Math::PI)))
    end
  end

  # A ginger cat asleep on the sill, breathing slowly.
  def cat
    nostroke
    fill rgb(70, 45, 25, 0.16)
    oval 552, 470, 86, 7, center: true
    fill gradient("#f0b46e", "#d9894a")
    @cat_body = oval(556, 452, 76, 30, center: true)
    oval 520, 446, 30, 24, center: true
    [[508, 428, 512, 440, 520, 436], [524, 426, 530, 438, 536, 436]].each do |x1, y1, x2, y2, x3, y3|
      shape do
        move_to x2, y2
        line_to x1, y1
        line_to x3, y3
      end
    end
    fill "#c47a3e"
    [[548, 440], [560, 439], [572, 441]].each { |x, y| rect x, y, 4, 9, curve: 2 }
    stroke "#c47a3e"
    strokewidth 5
    cap :curve
    nofill
    shape do # the tail, wrapped round the front
      move_to 592, 458
      curve_to 600, 470, 560, 474, 530, 466
    end
    stroke "#6b4a33"
    strokewidth 1.5
    line 512, 447, 518, 448
    line 523, 448, 529, 447
  end

  def breathe(time)
    @cat_body.style(height: (30 + Math.sin(time * 1.4) * 1.6).round(2), top: (452 - Math.sin(time * 1.4) * 0.8).round(2))
  end

  # ---- the controls ----

  def icon(name, x, y)
    stroke INK
    strokewidth 1.6
    cap :curve
    nofill
    case name
    when "sun"
      oval x, y, 8, center: true, fill: INK
      8.times do |i|
        a = i * Math::PI / 4
        line x + 6.5 * Math.cos(a), y + 6.5 * Math.sin(a), x + 9 * Math.cos(a), y + 9 * Math.sin(a)
      end
    when "rain", "storm"
      nostroke
      fill INK
      oval x - 3, y - 2, 9, center: true
      oval x + 2, y - 4, 10, center: true
      rect x - 7, y - 2, 15, 5, curve: 2
      stroke INK
      if name == "rain"
        [-4, 0, 4].each { |dx| line x + dx, y + 5, x + dx - 2, y + 9 }
      else
        nofill
        shape do
          move_to x + 1, y + 3
          line_to x - 2, y + 7
          line_to x + 2, y + 7
          line_to x - 1, y + 11
        end
      end
    when "snow"
      3.times do |i|
        a = i * Math::PI / 3 + Math::PI / 2
        line x - 8 * Math.cos(a), y - 8 * Math.sin(a), x + 8 * Math.cos(a), y + 8 * Math.sin(a)
      end
    when "cards"
      rect x - 8, y - 5, 12, 9, curve: 2
      rect x - 4, y - 2, 12, 9, curve: 2, fill: "#f2e9dc"
    end
  end

  def chip(label, name, current, &go)
    width = label.size * 8 + 58
    look = nil
    button = stack(width: width + 10, height: 40, margin_right: 10) do
      look = background(current ? white : rgb(255, 255, 255, 0.35), curve: 20)
      border rgb(90, 60, 40, current ? 0.18 : 0.12), curve: 20
      icon name, 24, 20
      para label, size: 13, weight: current ? "semibold" : "medium", stroke: INK, margin: [40, 11, 0, 0]
    end
    button.hover { look.fill = white unless current }
    button.leave { look.fill = rgb(255, 255, 255, 0.35) unless current }
    button.click(&go)
    button
  end

  def controls(current)
    names = WEATHERS.keys
    flow left: 0, top: 506, width: WIDTH do
      para WEATHERS[current][:mood], align: "center", size: 17, family: "Iowan Old Style, Georgia, serif",
        emphasis: "italic", stroke: INK
    end
    row = names.sum { |name| WEATHERS[name][:name].size * 8 + 68 } + "Postcards".size * 8 + 68 + 12
    flow left: (WIDTH - row) / 2, top: 552, width: row do
      names.each { |name| chip(WEATHERS[name][:name], name, name == current) { visit "/#{name}" } }
      stack(width: 12, height: 34) {}
      chip("Postcards", "cards", false) { visit "/" }
    end
    flow left: 0, top: 604, width: WIDTH do
      inscription "Keys 1 to 4 change the weather. Escape goes back to the postcards.", align: "center", stroke: MUTED
    end
    keypress do |key|
      index = %w[1 2 3 4].index(key)
      visit "/#{names[index]}" if index
      visit "/#{names[(names.index(current) + 1) % 4]}" if key == :right
      visit "/#{names[(names.index(current) - 1) % 4]}" if key == :left
      visit "/" if key == :escape
    end
  end

  # ---- one page per weather ----

  # The room, the window, and what the weather does outside it. The block
  # draws the moving parts; `animate` then runs `tick` thirty times a second.
  # Each page starts afresh: visit takes the last page's drawing and timers away.
  def room(name)
    w = WEATHERS[name]
    @motes = @drops_on_glass = @struck = nil
    wall
    title_bar
    window_frame(w)
    @scene = stack left: GX, top: GY, width: GW, height: GH do
      background gradient(*w[:sky])
      yield w, :sky
      landscape(w)
      tree(w)
      house(w)
      pond(w)
      snowman if name == "snow"
      yield w, :weather
      @flash = rect(0, 0, GW, GH, fill: clear_paint) if name == "storm"
    end
    stack(left: GX, top: GY, width: GW, height: GH) { glass_drops(name) }
    glazing(w)
    curtains
    sill
    sunbeam if name == "sun"
    plant
    cat
    mug
    controls(name)
    @frame = 0
    animate(30) do
      @frame += 1
      time = @frame / 30.0
      yield w, :tick, time
      rise_steam(@frame)
      breathe(time)
      slide_drops if @drops_on_glass
      float_motes(time) if @motes
    end
  end

  def title_bar
    flow left: 0, top: 24, width: WIDTH do
      para "WEATHER WINDOW", align: "center", size: 11, weight: "semibold", kerning: 3, stroke: MUTED
    end
  end

  def sun
    room("sun") do |w, part, time|
      case part
      when :sky
        sun_in_the_sky
        @clouds = [[cloud(40, 40, 0.8, rgb(255, 255, 255, 0.92)), 40.0, 5], [cloud(250, 96, 0.55, rgb(255, 255, 255, 0.8)), 250.0, 8]]
      when :weather
        start_birds
        start_glints
      when :tick
        turn_rays(time * 0.12)
        drift_clouds(1 / 30.0)
        fly_birds(1 / 30.0, time)
        twinkle(@frame)
      end
    end
  end

  def rain
    room("rain") do |w, part, time|
      case part
      when :sky
        @clouds = [[cloud(-20, 20, 1.1, rgb(214, 220, 226, 0.9)), -20.0, 6], [cloud(200, 50, 0.9, rgb(196, 204, 212, 0.9)), 200.0, 9],
          [cloud(330, 10, 1.0, rgb(222, 227, 232, 0.85)), 330.0, 5]]
      when :weather
        start_rain(90, 0.14, 620, rgb(226, 234, 242, 0.5))
      when :tick
        drift_clouds(1 / 30.0)
        fall_rain(1 / 30.0)
      end
    end
  end

  def snow
    room("snow") do |w, part, time|
      case part
      when :sky
        moon
      when :weather
        start_smoke
        start_snow
        nostroke
        fill "#f7fafd" # drifts on the ledge outside
        [[40, 110], [150, 80], [236, 120], [340, 90], [430, 110]].each { |x, d| oval x, GH + 4, d, 26, center: true }
      when :tick
        puff(@frame)
        fall_snow(1 / 30.0, time)
      end
    end
  end

  def storm
    room("storm") do |w, part, time|
      case part
      when :sky
        @clouds = [[cloud(-40, 0, 1.3, rgb(70, 76, 90, 0.95)), -40.0, 22], [cloud(170, 30, 1.1, rgb(84, 90, 104, 0.9)), 170.0, 30],
          [cloud(320, -10, 1.2, rgb(64, 70, 84, 0.95)), 320.0, 26]]
      when :weather
        start_rain(140, 0.32, 820, rgb(210, 220, 235, 0.45))
        @next_strike = 45
      when :tick
        drift_clouds(1 / 30.0)
        fall_rain(1 / 30.0)
        sway_tree(time)
        if @frame >= @next_strike
          @scene.append { strike }
          @next_strike = @frame + rand(165..240) # every six to eight seconds
        end
        flash
      end
    end
  end

  def drift_clouds(seconds)
    @clouds.each do |c|
      slot, _, speed = c
      c[1] += speed * seconds
      c[1] = -180.0 if c[1] > GW + 20
      slot.style(displace_left: c[1].round(1))
    end
  end

  # Raindrops on the pane itself. Every so often one lets go and runs down.
  def glass_drops(name)
    return unless %w[rain storm].include?(name)

    count = name == "storm" ? 18 : 11
    @drops_on_glass = Array.new(count) do
      size = rand(4.0..8.0)
      x = rand(8.0..GW - 8)
      y = rand(8.0..GH - 20)
      body = oval(x, y, size, size * 1.15, center: true, fill: rgb(255, 255, 255, 0.16), stroke: rgb(255, 255, 255, 0.35), strokewidth: 1)
      shine = oval(x - size * 0.18, y - size * 0.22, size * 0.3, center: true, fill: rgb(255, 255, 255, 0.7), stroke: clear_paint)
      { x: x, y: y, size: size, body: body, shine: shine, speed: 0.0, sliding: false }
    end
  end

  def slide_drops
    if @frame % 40 == 0 # let one go
      @drops_on_glass.reject { |d| d[:sliding] }.sample&.store(:sliding, true)
    end
    @drops_on_glass.each do |drop|
      next unless drop[:sliding]

      drop[:speed] = [drop[:speed] + 0.25, 5].min
      drop[:y] += drop[:speed]
      drop[:x] += rand(-0.4..0.4)
      if drop[:y] > GH + 10
        drop.merge!(x: rand(8.0..GW - 8), y: rand(-10.0..60.0), speed: 0.0, sliding: false)
      end
      drop[:body].style(left: drop[:x], top: drop[:y])
      drop[:shine].style(left: drop[:x] - drop[:size] * 0.18, top: drop[:y] - drop[:size] * 0.22)
    end
  end

  # Warm light through the glass, falling on the sill and the wall below,
  # with dust turning slowly in it.
  def sunbeam
    nostroke
    fill gradient(rgb(255, 232, 160, 0.34), rgb(255, 232, 160, 0))
    shape do
      move_to GX + 30, GY + GH + 16
      line_to GX + GW - 30, GY + GH + 16
      line_to GX + GW - 130, 548
      line_to GX - 70, 548
    end
    @motes = Array.new(14) do
      [oval(0, 0, rand(2.0..3.5), center: true, fill: rgb(255, 250, 225, 0.0)), rand(GX.to_f..GX + GW - 60), rand(460.0..560.0), rand(0.0..6.28)]
    end
  end

  def float_motes(time)
    @motes.each do |dot, x, y, phase|
      glow = [Math.sin(time * 0.7 + phase), 0].max
      dot.style(left: (x + Math.sin(time * 0.3 + phase) * 16 - (y - 460) * 0.5).round(1),
        top: (y + Math.cos(time * 0.23 + phase) * 10).round(1), fill: rgb(255, 250, 225, 0.75 * glow))
    end
  end

  # ---- the postcards ----

  def postcards
    wall
    flow left: 0, top: 96, width: WIDTH do
      para "Weather Window", align: "center", size: 34, weight: "light", stroke: INK,
        family: "Iowan Old Style, Georgia, serif", margin: [0, 0, 0, 6]
      para "Choose the weather, and it will be waiting outside.", align: "center", size: 14, stroke: MUTED
    end
    x = (WIDTH - (4 * 176 + 3 * 26)) / 2
    WEATHERS.each_with_index do |(name, w), i|
      postcard(name, w, x + i * 202, 234)
    end
    flow left: 0, top: 524, width: WIDTH do
      inscription "Or press 1, 2, 3 or 4.", align: "center", stroke: MUTED
    end
    keypress do |key|
      index = %w[1 2 3 4].index(key)
      visit "/#{WEATHERS.keys[index]}" if index
    end
  end

  def postcard(name, w, x, y)
    nostroke
    shadow = rect(x + 3, y + 8, 176, 236, curve: 12, fill: rgb(70, 45, 25, 0.10))
    card = stack left: x, top: y, width: 176, height: 236 do
      background white, curve: 12
      border rgb(90, 60, 40, 0.10), curve: 12
      stack left: 8, top: 8, width: 160, height: 136 do
        background gradient(*w[:sky])
        miniature(name, w)
        stamp(w)
      end
      para w[:name], size: 17, weight: "semibold", stroke: INK, margin: [14, 150, 0, 0]
      para w[:blurb], size: 11, stroke: MUTED, margin: [14, 2, 10, 0]
      inscription "#{w[:key]}  ·  /#{name}", stroke: rgb(141, 123, 106, 0.8), margin: [14, 8, 0, 0], family: "Menlo, monospace"
    end
    card.hover do
      card.displace(0, -5)
      shadow.style(top: y + 12, fill: rgb(70, 45, 25, 0.16))
    end
    card.leave do
      card.displace(0, 0)
      shadow.style(top: y + 8, fill: rgb(70, 45, 25, 0.10))
    end
    card.click { visit "/#{name}" }
  end

  # A stamp in the corner, franked with two wavy lines.
  def stamp(w)
    nostroke
    rect 128, 8, 24, 28, curve: 2, fill: white
    rect 131, 11, 18, 22, curve: 1, fill: gradient(w[:roof], w[:sky].last)
    oval 140, 20, 7, center: true, fill: rgb(255, 255, 255, 0.8)
    nofill
    stroke rgb(60, 50, 60, 0.35)
    strokewidth 1.2
    2.times do |i|
      shape do
        move_to 112, 14 + i * 6
        curve_to 122, 10 + i * 6, 130, 18 + i * 6, 140, 14 + i * 6
        curve_to 146, 11 + i * 6, 152, 16 + i * 6, 158, 14 + i * 6
      end
    end
  end

  # A little painting of each weather for its postcard.
  def miniature(name, w)
    nostroke
    case name
    when "sun"
      glow 116, 42, 70, rgb(255, 244, 200, 0.12), 5
      oval 116, 42, 26, center: true, fill: gradient("#fff6cc", "#ffd166")
      stroke rgb(255, 232, 160, 0.9)
      strokewidth 2
      cap :curve
      8.times { |i| a = i * Math::PI / 4; line 116 + 17 * Math.cos(a), 42 + 17 * Math.sin(a), 116 + 24 * Math.cos(a), 42 + 24 * Math.sin(a) }
      cloud(10, 30, 0.35, rgb(255, 255, 255, 0.9))
    when "rain", "storm"
      cloud(-4, 6, 0.7, name == "rain" ? rgb(220, 225, 232, 0.95) : rgb(70, 76, 90, 0.95))
      cloud(62, 18, 0.62, name == "rain" ? rgb(200, 207, 215, 0.95) : rgb(84, 90, 104, 0.95))
      stroke rgb(230, 236, 244, 0.6)
      strokewidth 1.2
      slant = name == "rain" ? 3 : 7
      dice = Random.new(name.size) # the same rain every time the postcards are drawn
      26.times { x = dice.rand(0..160); y = dice.rand(40..120); line x, y, x - slant, y + 11 }
      if name == "storm"
        stroke white
        strokewidth 2
        nofill
        shape do
          move_to 96, 46
          line_to 88, 70
          line_to 100, 74
          line_to 90, 100
        end
      end
    when "snow"
      glow 30, 30, 50, rgb(230, 236, 255, 0.08), 4
      oval 30, 30, 16, center: true, fill: "#f5f2e6"
      fill white
      dice = Random.new(3)
      34.times { oval dice.rand(0..160), dice.rand(0..120), dice.rand(2..4), center: true }
    end
    nostroke
    fill w[:far]
    shape do
      move_to 0, 104
      curve_to 40, 90, 90, 92, 160, 100
      line_to 160, 136
      line_to 0, 136
    end
    fill w[:near]
    shape do
      move_to 0, 120
      curve_to 50, 108, 110, 110, 160, 118
      line_to 160, 136
      line_to 0, 136
    end
    fill w[:walls]
    rect 108, 96, 22, 14
    fill w[:roof]
    shape do
      move_to 104, 97
      line_to 119, 86
      line_to 134, 97
    end
    fill w[:lamp] || "#a8d4ee"
    rect 114, 100, 5, 5
  end
end
