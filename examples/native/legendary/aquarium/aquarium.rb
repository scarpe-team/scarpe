# Aquarium: a little tank of fish, each with a mind of its own.
#
# Click the water to drop a pinch of food and watch them race for it.
# Click a fish to say hello. The moon button, or N, turns the lights down.

W, H = 880, 560
SURFACE = 24       # the top of the water
SAND = 486         # where the sand starts, give or take its ripples
FPS = 30
DAY_HINT = "Click the water to feed them. Click a fish to say hello."
NIGHT_HINT = "Shh, they are sleeping. Press Day to wake them."
INK = "#2a211d"    # every creature is outlined in the same warm near-black
KELP = {
  deep: ["#2e7d4f", "#3f9a5b", "#6cc26f"],
  bright: ["#2e7d4f", "#4caf64", "#8ed17a"],
  soft: ["#3f9a5b", "#6cc26f", "#a6de8a"],
  plum: ["#8e4f9e", "#b56cc4", "#dd9be6"],
}

CAST = [
  { name: "Marlow", kind: :clownfish, line: "Brave, mostly.", speed: 60, depth: 120..400, curious: true },
  { name: "Sapphire", kind: :tang, line: "Where was I going?", speed: 72, depth: 100..380, forgetful: true },
  { name: "Puff", kind: :puffer, line: "Please do not startle me.", speed: 28, depth: 270..430, restful: true, shy: true },
  { name: "Goldie", kind: :goldfish, line: "Is it dinner yet?", speed: 54, depth: 80..300, greedy: true },
]
SIZES = { clownfish: [96, 60], tang: [100, 64], puffer: [96, 88], goldfish: [104, 64], tetra: [36, 18] }

Fish = Struct.new(:name, :line, :kind, :speed, :depth, :x, :y, :vx, :vy, :goal, :rest,
  :facing, :slot, :parts, :phase, :traits, :puffed, keyword_init: true)
Flake = Struct.new(:x, :y, :sway, :art, :landed)
Bubble = Struct.new(:x, :y, :size, :speed, :phase, :ring, :shine, :home)
Leaf = Struct.new(:art, :x, :y, :reach, :phase, :shown)
Fleeting = Struct.new(:x, :y, :age, :life, :art) # hearts, ripples and snores

Shoes.app(title: "Aquarium", width: W, height: H, resizable: false) do
  # ---------------------------------------------------------------- drawing kit

  # A slot or a text block reads a Float from 0 to 1 as a fraction of its parent (0.5 is
  # halfway across), so a fish or a snore passing through there goes on a whole pixel.
  # Art takes any number as pixels, so the shapes need no help.
  def px(v)
    v > 0 && v <= 1 ? v.round : v
  end

  # A shape from path steps like [:curve_to, x1, y1, x2, y2, x, y], mirrored
  # left to right when the creature faces left, inside a box `width` wide.
  def outline(facing, width, steps)
    shape do
      steps.each do |command, *xy|
        xy = xy.each_slice(2).flat_map { |x, y| [facing > 0 ? x : width - x, y] }
        send(command, *xy)
      end
    end
  end

  # A round, shiny eye, and the closed one it wears at night.
  def eyes(facing, width, x, y, size)
    ex = facing > 0 ? x : width - x
    nostroke
    fill white
    open = [oval(ex, y, size, center: true)]
    fill INK
    open << oval(ex + facing * size * 0.12, y + size * 0.04, size * 0.6, center: true)
    fill white
    open << oval(ex + facing * size * 0.26, y - size * 0.14, size * 0.22, center: true)
    stroke INK
    strokewidth 1.8
    nofill
    shut = outline(facing, width, [[:move_to, x - size * 0.4, y], [:curve_to, x - size * 0.2, y + size * 0.35, x + size * 0.2, y + size * 0.35, x + size * 0.4, y]])
    shut.hide
    { open: open, shut: shut }
  end

  def smile(facing, width, x, y)
    stroke INK
    strokewidth 1.6
    nofill
    outline(facing, width, [[:move_to, x - 3, y], [:curve_to, x - 1, y + 2.5, x + 1, y + 2.5, x + 3, y - 0.5]])
  end

  # ---------------------------------------------------------------- the cast

  def clownfish(f)
    w = 96
    transform :center
    stroke INK
    strokewidth 2.2
    fill "#ff9d42".."#ff6b1f"
    tail = outline(f, w, [[:move_to, 24, 31], [:curve_to, 16, 22, 8, 13, 4, 15], [:curve_to, 9, 25, 9, 37, 4, 47], [:curve_to, 8, 49, 16, 40, 24, 31]])
    outline(f, w, [[:move_to, 36, 17], [:curve_to, 40, 5, 56, 3, 64, 15], [:line_to, 36, 17]])
    outline(f, w, [[:move_to, 44, 45], [:curve_to, 46, 54, 54, 56, 60, 45], [:line_to, 44, 45]])
    body = [[:move_to, 20, 31], [:curve_to, 26, 13, 54, 9, 74, 15], [:curve_to, 86, 19, 92, 27, 90, 32],
      [:curve_to, 88, 39, 74, 48, 52, 48], [:curve_to, 34, 48, 22, 41, 20, 31]]
    outline(f, w, body)
    strokewidth 1.6
    fill white
    [[68, 31, 9, 27], [47, 30.5, 12, 32], [29, 31, 7, 18]].each do |x, y, bw, bh|
      oval(f > 0 ? x : w - x, y, bw, bh, center: true)
    end
    strokewidth 2.2
    nofill
    outline(f, w, body)
    look = eyes(f, w, 79, 25, 13)
    smile(f, w, 86, 36)
    { tail: tail, eyes: look }
  end

  def tang(f)
    w = 100
    transform :center
    stroke INK
    strokewidth 2.2
    fill "#ffe14d".."#ffc21a"
    tail = outline(f, w, [[:move_to, 24, 32], [:line_to, 5, 15], [:curve_to, 11, 25, 11, 39, 5, 49], [:line_to, 24, 32]])
    fill "#4d90ff".."#1f4fd6"
    outline(f, w, [[:move_to, 20, 32], [:curve_to, 28, 12, 60, 4, 84, 17], [:curve_to, 94, 23, 97, 31, 95, 36],
      [:curve_to, 91, 46, 66, 58, 42, 53], [:curve_to, 29, 49, 20, 41, 20, 32]])
    nostroke
    fill "#15204a"
    outline(f, w, [[:move_to, 27, 33], [:curve_to, 36, 17, 62, 10, 80, 20], [:curve_to, 68, 20, 57, 24, 51, 30],
      [:curve_to, 58, 34, 64, 40, 58, 45], [:curve_to, 48, 40, 38, 38, 27, 33]])
    stroke INK
    strokewidth 1.6
    fill "#ffd21f"
    outline(f, w, [[:move_to, 66, 40], [:curve_to, 60, 46, 54, 50, 50, 48], [:curve_to, 54, 42, 60, 39, 66, 40]])
    look = eyes(f, w, 83, 27, 13)
    smile(f, w, 91, 37)
    { tail: tail, eyes: look }
  end

  # Puff has two shapes: calm, and puffed up for a moment when startled.
  def puffer(f, puffed)
    w = 96
    transform :center
    stroke INK
    strokewidth 2
    fill "#f6bd35"
    tail = outline(f, w, [[:move_to, 26, 44], [:curve_to, 18, 36, 11, 33, 8, 35], [:curve_to, 12, 41, 12, 47, 8, 53], [:curve_to, 11, 55, 18, 52, 26, 44]])
    size = puffed ? 66 : 54
    cx = f > 0 ? 52 : w - 52
    if puffed
      fill "#e8a326"
      star cx, 44, 26, size * 0.62, size * 0.5
    end
    nostroke
    fill "#ffe46b".."#f5b32e"
    oval cx, 44, size, size * 0.92, center: true
    fill "#fff5cc"
    oval cx + f * 3, 44 + size * 0.2, size * 0.7, size * 0.36, center: true
    fill "#c98a2e"
    [[-10, -14], [2, -18], [-18, -2], [-4, -6], [10, -10]].each do |dx, dy|
      oval cx + f * dx * size / 54.0, 44 + dy * size / 54.0, 5, center: true
    end
    stroke INK
    strokewidth 2
    nofill
    oval cx, 44, size, size * 0.92, center: true
    fill "#f6bd35"
    strokewidth 1.6
    outline(f, w, [[:move_to, 50, 50], [:curve_to, 44, 44, 38, 44, 36, 48], [:curve_to, 40, 54, 46, 54, 50, 50]])
    look = eyes(f, w, 52 + size * 0.3, 44 - size * 0.14, puffed ? 16 : 14)
    nofill
    strokewidth 1.8
    oval(f > 0 ? 52 + size * 0.46 : w - 52 - size * 0.46, 44 + size * 0.06, puffed ? 6 : 4, center: true)
    { tail: tail, eyes: look }
  end

  def goldfish(f)
    w = 104
    transform :center
    stroke INK
    strokewidth 2
    fill rgb(255, 150, 60, 0.82)
    tail = outline(f, w, [[:move_to, 32, 32], [:curve_to, 20, 14, 10, 4, 3, 9], [:curve_to, 11, 18, 11, 26, 7, 31],
      [:curve_to, 12, 35, 11, 45, 3, 56], [:curve_to, 12, 59, 22, 47, 32, 32]])
    outline(f, w, [[:move_to, 46, 18], [:curve_to, 48, 4, 64, 2, 72, 15], [:line_to, 46, 18]])
    fill "#ffc15a".."#ff7a24"
    outline(f, w, [[:move_to, 27, 32], [:curve_to, 33, 15, 59, 10, 79, 16], [:curve_to, 93, 20, 99, 28, 97, 33],
      [:curve_to, 95, 42, 81, 50, 59, 50], [:curve_to, 41, 50, 29, 42, 27, 32]])
    stroke rgb(255, 230, 170, 0.8)
    strokewidth 1.5
    nofill
    [[48, 28], [58, 36], [60, 22], [70, 30]].each do |x, y|
      outline(f, w, [[:move_to, x, y - 5], [:curve_to, x + 4, y - 3, x + 4, y + 3, x, y + 5]])
    end
    nostroke
    fill rgb(255, 105, 120, 0.4)
    oval(f > 0 ? 82 : w - 82, 37, 11, 6, center: true)
    look = eyes(f, w, 84, 26, 14)
    smile(f, w, 92, 37)
    { tail: tail, eyes: look }
  end

  def tetra(f)
    w = 36
    transform :center
    stroke rgb(42, 33, 29, 0.55)
    strokewidth 1
    fill "#c9d6e6"
    tail = outline(f, w, [[:move_to, 9, 9], [:line_to, 1, 3], [:curve_to, 3, 7, 3, 11, 1, 15], [:line_to, 9, 9]])
    fill "#eef3f8"
    outline(f, w, [[:move_to, 6, 9], [:curve_to, 10, 3, 24, 2, 32, 7], [:curve_to, 35, 9, 35, 10, 32, 11], [:curve_to, 24, 16, 10, 15, 6, 9]])
    nostroke
    fill "#29d3ff"
    outline(f, w, [[:move_to, 10, 8], [:curve_to, 16, 4.5, 26, 4, 31, 7], [:curve_to, 26, 7.6, 16, 8.4, 10, 9.4]])
    fill "#ff4d5e"
    outline(f, w, [[:move_to, 8, 10], [:curve_to, 12, 11, 18, 11.5, 22, 12.5], [:curve_to, 18, 14.5, 12, 14, 8, 10]])
    look = eyes(f, w, 28.5, 7.5, 4.6)
    { tail: tail, eyes: look }
  end

  # Pinch looks at you, so he never needs turning round.
  def crab
    stroke "#c9443a"
    strokewidth 3
    cap :curve
    [[30, 36, 12, 44], [32, 42, 16, 52], [36, 46, 24, 56], [60, 36, 78, 44], [58, 42, 74, 52], [54, 46, 66, 56]].each do |x1, y1, x2, y2|
      line x1, y1, x2, y2 # legs
    end
    stroke INK
    strokewidth 2
    line 38, 26, 35, 12
    line 52, 26, 55, 12
    fill "#ff6f5e".."#e04a3e"
    shape do # claws, each a mitten with a notch
      move_to 20, 30
      curve_to 8, 30, 4, 18, 10, 10
      curve_to 12, 16, 16, 16, 18, 12
      curve_to 26, 16, 28, 26, 20, 30
    end
    shape do
      move_to 70, 30
      curve_to 82, 30, 86, 18, 80, 10
      curve_to 78, 16, 74, 16, 72, 12
      curve_to 64, 16, 62, 26, 70, 30
    end
    oval 45, 38, 52, 30, center: true
    nostroke
    fill rgb(255, 120, 130, 0.5)
    oval 32, 41, 8, 5, center: true
    oval 58, 41, 8, 5, center: true
    look = [eyes(1, 90, 35, 11, 9), eyes(1, 90, 55, 11, 9)]
    smile(1, 90, 45, 42)
    look
  end

  # An arched window or door: straight sides and a round top, `w` wide and `h` tall.
  def arch(x, top, w, h)
    shape do
      move_to x, top + h
      line_to x, top + w / 2.0
      curve_to x, top - w * 0.1, x + w, top - w * 0.1, x + w, top + w / 2.0
      line_to x + w, top + h
      line_to x, top + h
    end
  end

  # ---------------------------------------------------------------- the tank

  def water
    @water = background "#9fe3f2".."#1d76a6"
    nostroke
    fill rgb(10, 70, 110, 0.22)
    shape do # far rocks, for depth
      move_to 0, 420
      curve_to 60, 360, 130, 380, 190, 400
      curve_to 260, 340, 330, 360, 380, 410
      line_to 380, 500
      line_to 0, 500
    end
    shape do
      move_to 520, 420
      curve_to 580, 350, 660, 330, 720, 380
      curve_to 780, 340, 850, 360, 880, 380
      line_to 880, 500
      line_to 520, 500
    end
    @rays = [[110, 46], [280, 64], [450, 40], [610, 70], [770, 50]].map do |x, width|
      fill rgb(255, 255, 250, 0.16)..rgb(255, 255, 250, 0)
      shape do
        move_to x, 0
        line_to x + width, 0
        line_to x + width + 170, 470
        line_to x + 60, 470
      end
    end
  end

  def surface
    nostroke
    fill rgb(255, 255, 255, 0.22)
    @surface = shape do
      move_to(-60, 0)
      line_to 940, 0
      line_to 940, SURFACE - 6
      8.times { |i| curve_to 940 - i * 125 - 40, SURFACE + 4, 940 - i * 125 - 85, SURFACE - 14, 940 - (i + 1) * 125, SURFACE - 6 }
    end
  end

  def sand
    nostroke
    fill "#f7e1b2".."#d8b276"
    shape do
      move_to 0, SAND
      curve_to 160, SAND - 12, 300, SAND + 10, 440, SAND - 2
      curve_to 580, SAND - 14, 720, SAND + 8, 880, SAND - 6
      line_to 880, H
      line_to 0, H
    end
    stroke rgb(170, 125, 70, 0.35)
    strokewidth 1.5
    nofill
    [[40, 520, 90], [300, 536, 120], [520, 512, 80], [690, 540, 110], [150, 548, 70]].each do |x, y, len|
      shape do
        move_to x, y
        curve_to x + len * 0.3, y - 5, x + len * 0.6, y + 5, x + len, y
      end
    end
    pebbles = Random.new(3)
    colors = ["#f7a6b8", "#9ad0ec", "#c5b3e6", "#f7d488", "#a8e0c0", "#ffffff", "#f4b183"]
    nostroke
    34.times do
      x = pebbles.rand(10..870)
      fill colors[pebbles.rand(colors.size)]
      oval x, pebbles.rand(SAND + 10..H - 8), pebbles.rand(7..14), pebbles.rand(5..9), center: true
    end
  end

  # Sunlight through ripples makes soft shapes that dance on the sand.
  def caustics
    nostroke
    light = Random.new(5)
    Array.new(16) do
      x = light.rand(20..860)
      oval x, light.rand(SAND + 4..H - 14), light.rand(40..90), light.rand(8..14), center: true, fill: rgb(255, 255, 235, 0)
    end
  end

  def shimmer
    return if @dusk >= 1

    @caustics.each_with_index do |spot, i|
      glow = (Math.sin(@clock * 1.4 + i * 2.1) + 1) / 2
      spot.style(fill: rgb(255, 255, 235, (0.08 + 0.2 * glow) * (1 - @dusk)))
    end
  end

  def castle
    stroke "#4d4468"
    strokewidth 2
    fill "#d3caeb".."#a99fcb"
    rect 110, 392, 104, 98
    5.times { |i| rect 110 + i * 22.5, 380, 14, 14 }
    rect 72, 322, 46, 168
    rect 206, 352, 40, 138
    fill "#ffa3b5".."#ef5f7e"
    shape { move_to 64, 324; line_to 95, 258; line_to 126, 324; line_to 64, 324 }
    shape { move_to 198, 354; line_to 226, 300; line_to 254, 354; line_to 198, 354 }
    line 95, 258, 95, 238
    line 226, 300, 226, 282
    fill "#3cc9b4"
    transform :corner
    @flags = [shape { move_to 95, 238; line_to 114, 243; line_to 95, 249 }, shape { move_to 226, 282; line_to 243, 287; line_to 226, 292 }]
    stroke rgb(77, 68, 104, 0.25)
    strokewidth 1.5
    [[78, 360, 104], [80, 440, 112], [120, 420, 148], [180, 452, 208], [212, 400, 240], [212, 460, 240]].each do |x, y, x2|
      line x, y, x2, y
    end
    stroke "#4d4468"
    strokewidth 2
    fill "#4a3f6b"
    @windows = [[87, 344], [87, 404], [123, 412], [187, 412], [218, 378]].map do |x, y|
      arch x, y - 1, 16, 23
      [x + 8, y + 11] # where its glow goes at night
    end
    arch 146, 440, 32, 50 # the door
    nostroke
    fill "#5fae6e"
    [[74, 488, 30, 12], [118, 490, 24, 10], [200, 489, 34, 12], [244, 490, 16, 8]].each do |x, y, bw, bh|
      oval x, y, bw, bh, center: true
    end
  end

  def chest
    nostroke
    fill rgb(255, 214, 90, 0.35)
    @gleam = oval 655, 458, 90, 40, center: true, hidden: true
    stroke INK
    strokewidth 2
    fill "#6b3f1f"
    @lid_open = shape { move_to 622, 462; line_to 626, 424; curve_to 640, 412, 672, 412, 686, 424; line_to 690, 462 }
    @lid_open.hide
    fill "#a86b3c".."#7b4a24"
    rect 620, 462, 70, 32, curve: 3
    fill "#f2c14e"
    nostroke
    @coins = [[636, 460], [648, 457], [662, 459], [674, 461]].map { |x, y| oval x, y, 10, 6, center: true, hidden: true }
    stroke INK
    fill "#f2c14e"
    rect 632, 462, 7, 32
    rect 671, 462, 7, 32
    fill "#a86b3c".."#8a5530"
    @lid = shape { move_to 618, 464; curve_to 618, 444, 692, 444, 692, 464; line_to 618, 464 }
    fill "#f2c14e"
    rect 650, 466, 10, 10, curve: 2
  end

  # Kelp: a swaying stem with blades on alternate sides. The higher a blade grows,
  # the further it sways.
  def weed(x, blades, colors)
    cap :curve
    strokewidth 3
    stem = Array.new(blades) do |i|
      stroke colors[i * colors.size / blades]
      y = SAND + 8 - i * 16
      line x, y, x, y - 16
    end
    nostroke
    leaves = Array.new(blades) do |i|
      fill colors[i * colors.size / blades]
      side = i.even? ? 1 : -1
      y = SAND - 8 - i * 16
      art = shape(left: x, top: y) do
        move_to 0, 0
        curve_to side * 3, -12, side * 14, -24, side * 24, -28
        curve_to side * 16, -16, side * 8, -6, 0, 0
      end
      Leaf.new(art, x, y, (i + 1).to_f / blades, x * 0.013, nil)
    end
    { stem: stem, leaves: leaves }
  end

  def sway(weed)
    offsets = weed[:leaves].map do |leaf|
      (leaf.x + Math.sin(@clock * 0.9 + leaf.phase - leaf.reach * 2.4) * 18 * leaf.reach**1.5).round(1)
    end
    weed[:leaves].each_with_index do |leaf, i|
      next if offsets[i] == leaf.shown

      leaf.shown = offsets[i]
      leaf.art.left = offsets[i]
      weed[:stem][i].style(left: i.zero? ? leaf.x : offsets[i - 1], x2: offsets[i])
    end
  end

  # ---------------------------------------------------------------- creatures

  def dress(fish)
    fish.slot.clear do
      fish.parts = case fish.kind
                   when :clownfish then clownfish(fish.facing)
                   when :tang then tang(fish.facing)
                   when :puffer then puffer(fish.facing, fish.puffed)
                   when :goldfish then goldfish(fish.facing)
                   else tetra(fish.facing)
                   end
    end
    close_eyes(fish.parts[:eyes], true) if @asleep
  end

  def hatch(name:, kind:, line:, speed:, depth:, **traits)
    w, h = SIZES[kind]
    x = rand(120..W - 120).to_f
    y = rand(depth).to_f
    slot = stack(left: x - w / 2, top: y - h / 2, width: w, height: h) {}
    fish = Fish.new(name: name, line: line, kind: kind, speed: speed, depth: depth, x: x, y: y, vx: 0.0, vy: 0.0,
      facing: [1, -1].sample, slot: slot, phase: rand * 6, traits: traits, rest: 0.0, puffed: false)
    dress(fish)
    fish
  end

  def new_goal(fish)
    fish.goal = [rand(70..W - 70).to_f, rand(@night ? (fish.depth.max - 60)..(SAND - 40) : fish.depth).to_f]
  end

  def mouth(fish)
    [fish.x + fish.facing * SIZES[fish.kind][0] * 0.42, fish.y]
  end

  def nearest_flake(fish)
    at = mouth(fish)
    @flakes.min_by { |flake| Math.hypot(flake.x - at[0], flake.y - at[1]) }
  end

  # The heart of it: every fish steers towards a goal, easing its speed up and
  # down, and turns round when its goal is behind it.
  def swim(fish, dt, goal: nil, speed: nil)
    food = goal.nil? && !@night && nearest_flake(fish)
    if food
      goal = [food.x, food.y]
      speed = fish.speed * (fish.traits[:greedy] ? 3.2 : 2.3)
    end
    goal, speed = mood(fish) if goal.nil? && !food
    unless goal
      fish.rest -= dt
      new_goal(fish) if fish.goal.nil? && fish.rest <= 0
      new_goal(fish) if fish.traits[:forgetful] && rand < dt * 0.3
      goal = fish.goal || [fish.x, fish.y]
    end
    speed ||= fish.speed * (@night ? 0.4 : 1)

    dx = goal[0] - fish.x
    dy = goal[1] - fish.y
    distance = Math.hypot(dx, dy)
    if distance < 16 && !food && fish.goal
      fish.goal = nil
      fish.rest = fish.traits[:restful] ? rand(1.0..3.0) : rand(0.0..0.6)
    end
    want = distance < 1 ? 0 : speed * [distance / 80.0, 1].min / distance
    ease = [dt * (food ? 3.5 : 1.3), 1].min
    fish.vx += (dx * want - fish.vx) * ease
    fish.vy += (dy * want * 0.6 - fish.vy) * ease
    fish.x = (fish.x + fish.vx * dt).clamp(40, W - 40)
    fish.y = (fish.y + fish.vy * dt).clamp(SURFACE + 30, SAND - 20)
    make_room(fish) if @fish.include?(fish)
    turn(fish) if fish.vx * fish.facing < -6
    show(fish)
  end

  # Fish give each other a little room, so a crowd at dinner stacks up instead of piling up.
  def make_room(fish)
    @fish.each do |other|
      next if other.equal?(fish)

      dx = fish.x - other.x
      dy = fish.y - other.y
      room = (SIZES[fish.kind][1] + SIZES[other.kind][1]) * 0.4
      next if dx.abs > 60 || dy.abs > room

      fish.y += (dy.negative? ? -1 : 1) * [(room - dy.abs) * 0.1, 1.2].min
    end
  end

  # Marlow comes over to see what the pointer is up to; Puff keeps well away from it.
  def mood(fish)
    return if @night || @pointer.nil?

    dx = fish.x - @pointer[0]
    dy = fish.y - @pointer[1]
    distance = Math.hypot(dx, dy)
    if fish.traits[:curious] && distance < 260 && distance > 70
      [[@pointer[0] + (dx.positive? ? 70 : -70), @pointer[1]], fish.speed * 1.3]
    elsif fish.traits[:shy] && distance < 110
      [[fish.x + dx / distance * 120, fish.y + dy / distance * 60], fish.speed * 2.4]
    end
  end

  def turn(fish)
    fish.facing = -fish.facing
    dress(fish)
  end

  def show(fish)
    w, h = SIZES[fish.kind]
    bob = Math.sin(@clock * 2 + fish.phase) * 2
    fish.slot.move(px((fish.x - w / 2).round(1)), px((fish.y - h / 2 + bob).round(1)))
    beat = 5 + Math.hypot(fish.vx, fish.vy) / 12
    fish.parts[:tail].style(rotate: (Math.sin(@clock * beat + fish.phase) * 9).round(1))
  end

  # The school follows its leader, each tetra keeping its own place in the group.
  def school(dt)
    swim(@leader, dt)
    @zips.each do |zip|
      spot = [@leader.x + zip.traits[:dx] * @leader.facing, @leader.y + zip.traits[:dy]]
      if @flakes.any? && !@night
        swim(zip, dt)
      else
        swim(zip, dt, goal: spot, speed: 110)
      end
    end
  end

  def close_eyes(eyes, asleep)
    eyes[:open].each { |part| part.hidden = asleep }
    eyes[:shut].hidden = !asleep
  end

  def scuttle(dt)
    @pinch[:rest] -= dt
    if @pinch[:rest] <= 0 && !@night
      @pinch[:goal] = rand(300..560).to_f
      @pinch[:rest] = rand(3.0..7.0)
    end
    dx = @pinch[:goal] - @pinch[:x]
    step = dx.clamp(-40 * dt, 40 * dt)
    @pinch[:x] += step
    hop = step.abs > 0.1 ? Math.sin(@clock * 18).abs * -2 : 0
    @pinch[:slot].move((@pinch[:x] - 45).round(1), (SAND - 28 + hop).round(1))
  end

  # ---------------------------------------------------------------- food and fuss

  def feed(x, y)
    ripple(x, y)
    7.times do
      fx = x + rand(-26.0..26.0)
      fy = y + rand(-10.0..10.0)
      art = nil
      @below.append do
        fill ["#e8743b", "#f2b134", "#c9543a"].sample
        nostroke
        art = shape(left: fx, top: fy) do
          move_to 0, 0
          line_to rand(4.0..6.0), rand(-1.0..1.0)
          line_to rand(4.0..6.0), rand(4.0..6.0)
          line_to rand(-1.0..1.0), rand(4.0..5.0)
        end
      end
      @flakes << Flake.new(fx, fy, rand * 6, art, nil)
    end
  end

  def ripple(x, y)
    @below.append do
      nofill
      strokewidth 2
      stroke rgb(255, 255, 255, 0.8)
      @fleeting << Fleeting.new(x, y, 0.0, 0.6, oval(x, y, 8, center: true))
    end
  end

  def heart(x, y)
    @below.append do
      nostroke
      fill "#ff6f91"
      art = shape(left: x - 9, top: y - 16) do
        move_to 9, 16
        curve_to 0, 9, 0, 1, 5, 1
        curve_to 8, 1, 9, 4, 9, 5
        curve_to 9, 4, 10, 1, 13, 1
        curve_to 18, 1, 18, 9, 9, 16
      end
      @fleeting << Fleeting.new(x - 9, y - 16, 0.0, 1.3, art)
    end
  end

  def snore(fish)
    w, h = SIZES[fish.kind]
    x = fish.x + fish.facing * w * 0.3
    @above.append do
      art = para "z", size: 14, weight: "bold", stroke: rgb(220, 235, 255, 0.9), left: x, top: fish.y - h / 2
      @fleeting << Fleeting.new(x, fish.y - h / 2, 0.0, 2.2, art)
    end
  end

  def fade(dt)
    @fleeting.reject! do |thing|
      thing.age += dt
      k = thing.age / thing.life
      if k >= 1
        thing.art.remove
        next true
      end
      case thing.art
      when Shoes::Oval # a ripple spreads out
        d = (8 + 50 * k).round(1)
        thing.art.style(width: d, height: d, stroke: rgb(255, 255, 255, 0.8 * (1 - k)))
      when Shoes::Para # a snore drifts up and away
        thing.art.move(px(thing.x + Math.sin(k * 5) * 6), px(thing.y - 44 * k))
        thing.art.style(stroke: rgb(220, 235, 255, 0.9 * (1 - k)))
      else # a heart floats up
        thing.art.style(top: (thing.y - 30 * k).round(1), fill: rgb(255, 111, 145, 1 - k * k))
      end
      false
    end
  end

  def eat(dt)
    everyone = @fish + [@leader] + @zips
    @flakes.reject! do |flake|
      if flake.landed
        flake.landed += dt
      else
        flake.y += 16 * dt
        flake.x += Math.sin(@clock * 2 + flake.sway) * 8 * dt
        flake.landed = 0.0 if flake.y > SAND + 4
      end
      flake.art.move(flake.x.round(1), flake.y.round(1))
      eater = everyone.find do |fish|
        at = mouth(fish)
        Math.hypot(flake.x - at[0], flake.y - at[1]) < 14
      end
      heart(*mouth(eater)) if eater
      gone = eater || (flake.landed && flake.landed > 8)
      flake.art.remove if gone
      gone
    end
  end

  # ---------------------------------------------------------------- bubbles

  # A bubble is a thin ring with a glint. `home` is :castle or :chest, where it comes from.
  def bubble(home, x, y, size)
    stroke rgb(255, 255, 255, 0.75)
    strokewidth 1.2
    fill rgb(255, 255, 255, 0.14)
    ring = oval(x, y, size, center: true)
    nostroke
    fill rgb(255, 255, 255, 0.85)
    shine = oval(x - size * 0.2, y - size * 0.2, size * 0.3, center: true)
    Bubble.new(x.to_f, y.to_f, size, rand(34.0..60.0), rand * 6, ring, shine, home)
  end

  # Castle bubbles go round and round; chest bubbles wait below the window for a burst.
  def rise(dt)
    @bubbles.each do |b|
      next if b.y > H

      b.y -= b.speed * dt
      if b.y < SURFACE + 6
        b.x, b.y = b.home == :chest ? [655.0, H + 40.0] : [95.0 + rand(-3.0..3.0), 330.0 + rand(0.0..160.0)]
      end
      x = b.x + Math.sin(@clock * 3 + b.phase) * 3
      b.ring.move(x.round(1), b.y.round(1))
      b.shine.move((x - b.size * 0.2).round(1), (b.y - b.size * 0.2).round(1))
    end
  end

  # Every eight seconds the chest lid pops and lets out a burst of bubbles.
  def treasure(frame)
    open = frame % (8 * FPS) < 1.6 * FPS && frame > FPS * 2
    return if open == @chest_open

    @chest_open = open
    @lid.hidden = open
    @lid_open.hidden = !open
    @gleam.hidden = !open
    @coins.each { |coin| coin.hidden = !open }
    return unless open

    @bubbles.select { |b| b.home == :chest }.each_with_index do |b, i|
      b.x = 640.0 + i * 4
      b.y = SAND - 10.0 + i * 7
    end
  end

  # ---------------------------------------------------------------- day and night

  def mix(day, night, k)
    day.zip(night).map { |a, b| (a + (b - a) * k).round }
  end

  def dusk(dt)
    target = @night ? 1.0 : 0.0
    return if @dusk == target

    @dusk = @dusk < target ? [@dusk + dt / 2.0, 1.0].min : [@dusk - dt / 2.0, 0.0].max
    k = @dusk * @dusk * (3 - 2 * @dusk) # ease in and out
    @water.fill = rgb(*mix([159, 227, 242], [20, 52, 96], k))..rgb(*mix([29, 118, 166], [4, 14, 34], k))
    @veil.fill = rgb(4, 12, 36, 0.45 * k)
    @rays.each { |ray| ray.fill = rgb(255, 255, 250, 0.16 * (1 - k) + 0.05 * k)..rgb(255, 255, 250, 0) }
    @glows.each_with_index { |glow, i| glow.fill = rgb(255, 210, 110, (i % 4 == 3 ? 0.95 : 0.07) * k) }
    @moon.each { |ring| ring.fill = rgb(200, 220, 255, 0.011 * k) }
    @pills.each { |pill| pill.fill = rgb(*mix([8, 40, 70], [150, 180, 255], k), 0.3 - 0.16 * k) }
    asleep = @dusk > 0.5
    return if asleep == @asleep

    @asleep = asleep
    (@fish + [@leader] + @zips).each { |fish| close_eyes(fish.parts[:eyes], asleep) }
    @pinch[:eyes].each { |eyes| close_eyes(eyes, asleep) }
  end

  def glimmer
    return unless @dusk > 0

    @plankton.each_with_index do |dot, i|
      twinkle = (Math.sin(@clock * 1.7 + i * 1.3) + 1) / 2
      drift = Math.sin(@clock * 0.5 + i) * 0.3
      dot.style(left: (dot.left + drift).round(1), fill: rgb(130, 255, 220, (0.15 + 0.7 * twinkle) * @dusk))
    end
  end

  def toggle_night
    @night = !@night
    @switch_label.replace(@night ? "Day" : "Night")
    @hint.replace(@night ? NIGHT_HINT : DAY_HINT)
    @sun.each { |part| part.hidden = !@night }
    @moon_icon.each { |part| part.hidden = @night }
    @fish.each { |fish| new_goal(fish) }
    new_goal(@leader)
  end

  # ---------------------------------------------------------------- saying hello

  def hello(fish)
    @greeting = { fish: fish, age: 0.0 }
    @greet_name.replace fish.name
    @greet_line.replace fish.line
    @card.show
    place_card
    return unless fish.kind == :puffer

    fish.puffed = true
    dress(fish)
  end

  def place_card
    fish = @greeting[:fish]
    w, h = SIZES[fish.kind]
    left = (fish.x - 90).clamp(10, W - 190)
    top = [fish.y - h / 2 - 70, SURFACE + 6].max
    @card.move(left.round, top.round)
  end

  def greet(dt)
    return unless @greeting

    @greeting[:age] += dt
    place_card
    return if @greeting[:age] < 3

    fish = @greeting[:fish]
    if fish.puffed
      fish.puffed = false
      dress(fish)
    end
    @card.hide
    @greeting = nil
  end

  def fish_at(x, y)
    (@fish + [@leader] + @zips).find do |fish|
      w, h = SIZES[fish.kind]
      (x - fish.x).abs < w * 0.4 && (y - fish.y).abs < h * 0.4
    end
  end

  def pill(left, width)
    stack(left: left, top: 14, width: width, height: 36) do
      @pills << background(rgb(8, 40, 70, 0.3), curve: 18)
      yield
    end
  end

  # ---------------------------------------------------------------- the scene

  @night = false
  @asleep = false
  @dusk = 0.0
  @clock = 0.0
  @flakes = []
  @fleeting = []
  @pills = []

  water
  sand
  @caustics = caustics
  castle
  chest
  # kelp behind the fish: where, how many blades, and which greens
  @weeds = [[34, 13, :deep], [276, 9, :bright], [300, 12, :soft], [470, 8, :plum], [566, 14, :deep],
    [760, 11, :soft], [842, 15, :bright]].map { |x, blades, colors| weed(x, blades, KELP[colors]) }

  @bubbles = Array.new(10) { |i| bubble(:castle, 95, 330 - i * 30, rand(5..11)) }
  @bubbles += Array.new(8) { bubble(:chest, 655, H + 40, rand(6..12)) }

  @pinch = { x: 420.0, goal: 420.0, rest: 2.0 }
  @pinch[:slot] = stack(left: 375, top: SAND - 28, width: 90, height: 60) { @pinch[:eyes] = crab }

  @fish = CAST.map { |cast| hatch(**cast) }
  # the Zips: a leader who wanders, and six who keep their places around it
  zips = { name: "The Zips", kind: :tetra, line: "We go everywhere together.", speed: 84, depth: 90..330 }
  @leader = hatch(**zips, forgetful: true)
  @zips = [[-36, -18], [-40, 16], [-72, 0], [-78, -30], [-84, 30], [-112, -10]].map do |dx, dy|
    hatch(**zips, dx: dx, dy: dy)
  end
  @leader.x, @leader.y = 600.0, 200.0
  @zips.each { |zip| zip.x, zip.y = 600.0 + zip.traits[:dx], 200.0 + zip.traits[:dy] }

  # and two in front, for depth
  @weeds += [[14, 8, :bright], [700, 9, :plum]].map { |x, blades, colors| weed(x, blades, KELP[colors]) }
  @below = stack(left: 0, top: 0, width: W, height: H) {}
  surface
  @veil = rect 0, 0, W, H, fill: rgb(4, 12, 36, 0), stroke: rgb(0, 0, 0, 0)

  nostroke
  @moon = Array.new(16) { |i| oval 690, -10, 360 - i * 21, center: true, fill: rgb(200, 220, 255, 0) }
  @glows = @windows.flat_map do |x, y|
    halo = [46, 34, 24].map { |d| oval(x, y + 2, d, center: true, fill: rgb(255, 204, 102, 0)) }
    fill rgb(255, 214, 110, 0)
    halo + [arch(x - 6, y - 8, 12, 17)]
  end
  sky = Random.new(11)
  @plankton = Array.new(34) { oval sky.rand(20..860), sky.rand(60..460), sky.rand(2..4), center: true, fill: rgb(130, 255, 220, 0) }

  @above = stack(left: 0, top: 0, width: W, height: H) {}

  # the speech card that pops up over a fish you click
  @card = stack(left: 0, top: 0, width: 180, height: 66, hidden: true) do
    background white, curve: 14, height: 58
    nostroke
    fill white
    shape { move_to 80, 57; line_to 90, 66; line_to 100, 57 }
    @greet_name = para "", align: "center", size: 13, weight: "bold", stroke: INK, margin: [0, 9, 0, 0]
    @greet_line = para "", align: "center", size: 11, stroke: "#6b625c", emphasis: "italic", margin: [0, 2, 0, 0]
  end

  pill(16, 132) do
    para "Aquarium", size: 15, weight: "semibold", stroke: white, margin: [22, 9, 0, 0]
  end
  pill(W / 2 - 200, 400) do
    @hint = para DAY_HINT, align: "center", size: 12, stroke: white, margin: [0, 11, 0, 0]
  end
  switch = pill(W - 118, 102) do
    @switch_label = para "Night", size: 14, weight: "semibold", stroke: white, margin: [42, 10, 0, 0]
    nostroke
    @moon_icon = [oval(24, 18, 16, center: true, fill: "#fff3c4"), oval(29, 14, 14, center: true, fill: rgb(40, 110, 150))]
    @sun = [oval(24, 18, 12, center: true, fill: "#ffd45c", hidden: true)]
    strokewidth 2
    stroke "#ffd45c"
    cap :curve
    8.times do |i|
      a = i * Math::PI / 4
      @sun << line(24 + 8.5 * Math.cos(a), 18 + 8.5 * Math.sin(a), 24 + 11.5 * Math.cos(a), 18 + 11.5 * Math.sin(a), hidden: true)
    end
  end
  switch.click { toggle_night }

  click do |_button, x, y|
    next if y < 56 && (x < 150 || x > W - 120)

    fish = fish_at(x, y)
    if fish
      hello(fish)
    elsif y > SURFACE && y < SAND
      @night ? ripple(x, y) : feed(x, y)
    end
  end

  motion { |x, y| @pointer = y > SURFACE && y < SAND ? [x, y] : nil }
  leave { @pointer = nil }
  keypress { |key| toggle_night if key == "n" }

  animate(FPS) do |frame|
    dt = 1.0 / FPS
    @clock = frame * dt
    @fish.each { |fish| swim(fish, dt) }
    school(dt)
    scuttle(dt)
    eat(dt)
    rise(dt)
    treasure(frame)
    fade(dt)
    greet(dt)
    dusk(dt)
    glimmer
    shimmer
    snore(@fish[2]) if @night && frame % (FPS * 2) == 0
    @weeds.each { |weed| sway(weed) }
    @rays.each_with_index { |ray, i| ray.style(rotate: (Math.sin(@clock * 0.4 + i) * 1.2).round(2)) }
    @flags.each_with_index { |flag, i| flag.style(rotate: (Math.sin(@clock * 3 + i) * 8).round(1)) }
    @surface.left = (Math.sin(@clock * 0.6) * 24).round(1)
  end
end
