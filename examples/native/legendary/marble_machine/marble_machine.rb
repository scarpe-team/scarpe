# Marble Machine: glass marbles tumble through brass pins and pile up in tubes.
#
# Click anywhere above the tubes to drop a marble there, or hold the button
# down and sweep to pour a stream. Space pours forty from the hopper, E empties
# the tubes, and the swatches choose a colour (the rainbow one takes turns).
#
# Pour enough from the middle and the tubes draw a bell curve: every pin sends
# a marble left or right more or less at random, and most of them end up
# somewhere near where they started. The card on the right counts the frames.

WIDTH, HEIGHT = 900, 640

LEFT_WALL, RIGHT_WALL = 40, 560      # the inside of the glass case
HOPPER_X = 300                       # the middle, where pours come from
PIN_TOP, PIN_ROWS = 132, 8           # the first row of pins, and how many rows
PIN_GAP_X, PIN_GAP_Y = 40, 34
TUBE_TOP, FLOOR = 398, 600           # the tubes the marbles land in
TUBES = 13
TUBE_WIDTH = 40

RADIUS = 6
PIN_RADIUS = 4
GRAVITY = 1500.0                     # pixels a second, every second
BOUNCE = 0.3                         # how much speed survives a knock
GRIP = 0.85                          # how much speed along a pin's edge survives it
NUDGE = 30.0                         # the little bit of chance in every knock
STEP = 1 / 120.0                     # two small physics steps a frame
LAYER = 10.4                         # how far apart the rows of a pile sit
TAIL = 7                             # dots in a marble's comet tail
TAIL_GAP = 4.5                       # and the pixels between them

JEWELS = [
  [233, 69, 96], [255, 126, 95], [255, 187, 64], [160, 222, 92], [38, 196, 141],
  [46, 196, 226], [72, 126, 255], [150, 104, 245], [233, 110, 214],
]
BRASS = ["#ffe7a6", "#b98231"]
INK = "#f4efe6"
MUTED = "#8f93a6"

Marble = Struct.new(:x, :y, :vx, :vy, :color, :body, :shine, :tail, :path, :tube, :state, :wait)

Shoes.app(title: "Marble Machine", width: WIDTH, height: HEIGHT, resizable: false) do
  # ---- colours ----

  def mix(color, other, amount)
    color.zip(other).map { |c, o| (c + (o - c) * amount).round }
  end

  # Light from the top left: a glassy marble is paler there and deeper below.
  def glass(color)
    gradient(rgb(*mix(color, [255, 255, 255], 0.45)), rgb(*mix(color, [10, 10, 30], 0.35)), angle: 35)
  end

  def next_color
    return JEWELS[@color] unless @color == :rainbow

    @turn = (@turn + 1) % JEWELS.size
    JEWELS[@turn]
  end

  # ---- making marbles ----

  def tail_size(i)
    RADIUS * 1.6 * (1 - i / TAIL.to_f)
  end

  def drop_marble(x, y, color = next_color)
    x = x.clamp(LEFT_WALL + RADIUS + 1, RIGHT_WALL - RADIUS - 1)
    y = y.clamp(46, TUBE_TOP - 30)
    tail = nil
    @tails.append do
      tail = (0...TAIL).map do |i|
        oval(x, y, tail_size(i), center: true, stroke: rgb(0, 0, 0, 0), fill: rgb(*color, 0.3 * (1 - i / TAIL.to_f) ** 1.5))
      end
    end
    body = shine = nil
    @glass.append do
      body = oval(x, y, RADIUS * 2, center: true, stroke: rgb(0, 0, 0, 0.25), fill: glass(color))
      shine = oval(x - 2, y - 2.5, 4, center: true, stroke: rgb(0, 0, 0, 0), fill: rgb(255, 255, 255, 0.8))
    end
    marble = Marble.new(x, y, rand(-15.0..15.0), 0.0, color, body, shine, tail, [], nil, :rolling, 0)
    @marbles << marble
    marble
  end

  # A soft ring where a marble was dropped by hand.
  def ripple(x, y)
    ring = nil
    @glass.append { ring = oval(x, y, 10, center: true, fill: rgb(0, 0, 0, 0), stroke: rgb(255, 255, 255, 0.5), strokewidth: 1.5) }
    @ripples << [ring, 0]
  end

  def spread_ripples
    @ripples.each do |ripple|
      ring, age = ripple
      ripple[1] = age += 1
      ring.style(width: 10 + age * 1.6, height: 10 + age * 1.6, stroke: rgb(255, 255, 255, 0.5 * (1 - age / 24.0)))
    end
    done, @ripples = @ripples.partition { |_, age| age >= 24 }
    done.each { |ring, _| ring.remove }
  end

  # ---- the pins ----

  # Even rows sit over the middles of the tubes, odd rows over the walls between them.
  def pin_row_x(row)
    row.even? ? (0...TUBES).map { |i| LEFT_WALL + TUBE_WIDTH / 2 + i * TUBE_WIDTH } :
                (1...TUBES).map { |i| LEFT_WALL + i * TUBE_WIDTH }
  end

  def build_pins
    @pins = (0...PIN_ROWS).map do |row|
      y = PIN_TOP + row * PIN_GAP_Y
      pin_row_x(row).map do |x|
        halo = oval(x, y, 26, center: true, fill: rgb(0, 0, 0, 0))
        glow = oval(x, y, 15, center: true, fill: rgb(0, 0, 0, 0))
        { x: x, y: y, halo: halo, glow: glow, heat: 0.0, color: nil }
      end
    end
    @pins.flatten.each do |pin|
      oval pin[:x], pin[:y] + 1.5, PIN_RADIUS * 2 + 1, center: true, fill: rgb(0, 0, 0, 0.35)
      oval pin[:x], pin[:y], PIN_RADIUS * 2, center: true, fill: gradient(*BRASS, angle: 35)
      oval pin[:x] - 1.2, pin[:y] - 1.4, 2.5, center: true, fill: rgb(255, 255, 255, 0.85)
    end
  end

  # The one pin a marble at (x, y) could be touching: the rows are too far apart for two.
  def pin_near(x, y)
    row = ((y - PIN_TOP) / PIN_GAP_Y).round
    return unless row.between?(0, PIN_ROWS - 1)

    pins = @pins[row]
    first = pins.first[:x]
    pins[((x - first) / PIN_GAP_X).round.clamp(0, pins.size - 1)]
  end

  def warm(pin, color)
    pin[:heat] = 1.0
    pin[:color] = color
    @warm << pin unless @warm.include?(pin)
  end

  def cool_pins
    @warm.each do |pin|
      pin[:heat] *= 0.9
      heat = pin[:heat] < 0.03 ? 0 : pin[:heat]
      pin[:halo].fill = rgb(*pin[:color], 0.18 * heat)
      pin[:glow].fill = rgb(*pin[:color], 0.4 * heat)
    end
    @warm.reject! { |pin| pin[:heat] < 0.03 }
  end

  # ---- physics ----

  # Knocks a marble off something round at (px, py). Returns true if they touched.
  def knock(marble, px, py, reach)
    dx = marble.x - px
    dy = marble.y - py
    distance = Math.hypot(dx, dy)
    return false if distance >= reach

    nx, ny = distance.zero? ? [0.0, -1.0] : [dx / distance, dy / distance]
    marble.x = px + nx * reach
    marble.y = py + ny * reach
    into = marble.vx * nx + marble.vy * ny
    return true if into > 0 # already moving away

    marble.vx -= (1 + BOUNCE) * into * nx
    marble.vy -= (1 + BOUNCE) * into * ny
    # Grip takes some of the speed along the pin's edge, and a nudge adds a
    # little chance, so no two knocks are quite alike.
    edge = -marble.vx * ny + marble.vy * nx
    change = -(1 - GRIP) * edge + rand(-NUDGE..NUDGE)
    marble.vx += -ny * change
    marble.vy += nx * change
    true
  end

  # Two marbles that overlap push apart and trade some speed.
  def jostle(a, b)
    dx = b.x - a.x
    dy = b.y - a.y
    distance = Math.hypot(dx, dy)
    return if distance >= RADIUS * 2 || distance.zero?

    nx = dx / distance
    ny = dy / distance
    overlap = (RADIUS * 2 - distance) / 2
    a.x -= nx * overlap
    a.y -= ny * overlap
    b.x += nx * overlap
    b.y += ny * overlap
    closing = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny
    return if closing <= 0

    push = closing * (1 + BOUNCE) / 2
    a.vx -= push * nx
    a.vy -= push * ny
    b.vx += push * nx
    b.vy += push * ny
  end

  def fall(marble, seconds)
    marble.vy += GRAVITY * seconds
    marble.vx *= 0.975 # the air slows sideways drift, so marbles fall pin by pin
    speed = Math.hypot(marble.vx, marble.vy)
    if speed > 720
      marble.vx *= 720 / speed
      marble.vy *= 720 / speed
    end
    marble.x += marble.vx * seconds
    marble.y += marble.vy * seconds
  end

  def roll(marble)
    fall(marble, STEP)
    if (pin = pin_near(marble.x, marble.y)) && knock(marble, pin[:x], pin[:y], RADIUS + PIN_RADIUS)
      warm(pin, marble.color)
    end
    # the tops of the walls between the tubes are round, like pins
    if (marble.y - TUBE_TOP).abs < RADIUS + 2
      wall = LEFT_WALL + ((marble.x - LEFT_WALL) / TUBE_WIDTH).round * TUBE_WIDTH
      knock(marble, wall, TUBE_TOP, RADIUS + 2) if wall > LEFT_WALL && wall < RIGHT_WALL
    end
    if marble.x < LEFT_WALL + RADIUS
      marble.x = LEFT_WALL + RADIUS
      marble.vx = marble.vx.abs * BOUNCE
    elsif marble.x > RIGHT_WALL - RADIUS
      marble.x = RIGHT_WALL - RADIUS
      marble.vx = -marble.vx.abs * BOUNCE
    end
    land(marble) if marble.y > TUBE_TOP + RADIUS
  end

  # ---- the tubes ----

  # A pile is rows of three and two, each row nestled into the one below.
  def slots(tube, layer)
    middle = LEFT_WALL + tube * TUBE_WIDTH + TUBE_WIDTH / 2
    y = FLOOR - RADIUS - layer * LAYER
    offsets = layer.even? ? [-12, 0, 12] : [-6, 6]
    offsets.map { |dx| [middle + dx, y] }
  end

  def layers
    @layers ||= ((FLOOR - TUBE_TOP - RADIUS * 2) / LAYER).floor + 1
  end

  # The free place nearest to x on the lowest row that still has room, or nil when full.
  def free_slot(tube, x)
    pile = @piles[tube]
    layer = pile.size
    taken = pile.last && pile.last.size < slots(tube, layer - 1).size ? pile.last : nil
    layer -= 1 if taken # the top row still has room
    return if layer >= layers

    places = slots(tube, layer).each_with_index.reject { |_, i| taken&.include?(i) }
    place, index = places.min_by { |(px, _), _| (px - x).abs }
    [place, layer, index]
  end

  def land(marble)
    marble.tube ||= ((marble.x - LEFT_WALL) / TUBE_WIDTH).floor.clamp(0, TUBES - 1)
    left = LEFT_WALL + marble.tube * TUBE_WIDTH + 1.5 + RADIUS
    right = LEFT_WALL + (marble.tube + 1) * TUBE_WIDTH - 1.5 - RADIUS
    marble.x = marble.x.clamp(left, right)
    marble.vx *= 0.5
    return marble.state = :dropping if @door > 0

    found = free_slot(marble.tube, marble.x)
    return marble.state = :fading unless found

    (sx, sy), layer, index = found
    marble.x += (sx - marble.x) * 0.15 # drift towards its place on the way down
    settle(marble, sx, sy, layer, index) if marble.y >= sy
  end

  def settle(marble, x, y, layer, index)
    (@piles[marble.tube][layer] ||= []) << index
    marble.x = x
    marble.y = y
    marble.state = :settled
    marble.tail.each(&:remove)
    marble.tail = []
    @settled += 1
  end

  # Opens the floor: every settled marble falls out, a moment apart.
  def empty_tubes
    @marbles.each do |marble|
      next unless marble.state == :settled

      marble.state = :dropping
      marble.vy = 0.0
      marble.wait = (FLOOR - marble.y) / 12.0 + rand(0..3) # the bottom rows go first
    end
    @piles = Array.new(TUBES) { [] }
    @settled = 0
    @door_goal = 1
  end

  # True once the marble has fallen out of sight.
  def drop_out(marble)
    if marble.wait > 0
      marble.wait -= 1
      return false
    end
    fall(marble, 1 / 60.0)
    marble.y > HEIGHT + 20
  end

  # ---- every frame ----

  def step_world
    rolling = @marbles.select { |m| m.state == :rolling }
    2.times do
      rolling.each { |marble| roll(marble) }
      rolling = rolling.select { |m| m.state == :rolling }.sort_by!(&:y)
      rolling.each_with_index do |a, i|
        (i + 1...rolling.size).each do |j|
          b = rolling[j]
          break if b.y - a.y >= RADIUS * 2

          jostle(a, b)
        end
      end
    end
    gone = @marbles.select { |m| m.state == :dropping && drop_out(m) }
    @marbles.each { |m| fade(m) if m.state == :fading }
    gone += @marbles.select { |m| m.state == :faded }
    gone.each { |m| forget(m) }
  end

  # A marble with nowhere to go in a full tube shrinks away.
  def fade(marble)
    marble.shine.hide if marble.wait.zero?
    marble.wait += 1
    return marble.state = :faded if marble.wait >= 10

    size = (RADIUS * 2 * (1 - marble.wait / 10.0)).round(1)
    marble.body.style(width: size, height: size)
  end

  def forget(marble)
    marble.body.remove
    marble.shine.remove
    marble.tail.each(&:remove)
    @marbles.delete(marble)
  end

  def draw(marble)
    return if marble.state == :settled && marble.path.empty?

    x = marble.x.round(1)
    y = marble.y.round(1)
    marble.body.style(left: x, top: y)
    marble.shine.style(left: x - 2, top: y - 2.5)
    if marble.state == :settled
      marble.path.clear
      return
    end

    marble.path.unshift([x, y]) # the road behind it, fourteen frames long
    marble.path.pop if marble.path.size > 14
    draw_tail(marble)
  end

  # The tail's dots sit a few pixels apart along the road the marble came by,
  # so a fast marble draws a long streak and a slow one hardly any. Dots the
  # road is too short for wait under the marble.
  def draw_tail(marble)
    road = marble.path
    wanted = TAIL_GAP
    travelled = 0.0
    placed = 0
    road.each_cons(2) do |(ax, ay), (bx, by)|
      length = Math.hypot(bx - ax, by - ay)
      while placed < marble.tail.size && travelled + length >= wanted
        t = (wanted - travelled) / length
        marble.tail[placed].style(left: (ax + (bx - ax) * t).round(1), top: (ay + (by - ay) * t).round(1))
        placed += 1
        wanted += TAIL_GAP
      end
      travelled += length
      break if placed == marble.tail.size
    end
    marble.tail[placed..].each { |dot| dot.style(left: road[0][0], top: road[0][1]) }
  end

  # The two halves of the floor slide into the walls, a little every frame,
  # and slide back once the last marble has fallen out.
  def slide_doors
    @door_goal = 0 if @door_goal == 1 && @marbles.none? { |m| m.state == :dropping }
    return if @door == @door_goal

    @door = @door_goal > @door ? [@door + 0.125, 1].min : [@door - 0.125, 0].max
    half = (1 - @door) * 262
    left, right = @doors
    left.style(width: half)
    right.style(left: RIGHT_WALL + 2 - half, width: half)
  end

  def pour_tick
    if @pouring > 0
      @pour_clock += 1
      if @pour_clock % 4 == 0
        drop_marble(HOPPER_X + rand(-3.0..3.0), 58)
        @pouring -= 1
      end
    end
    held, x, y = mouse
    return unless @streaming && held == 1 && on_board?(x, y)

    @stream_clock += 1
    drop_marble(x + rand(-2.0..2.0), y) if @stream_clock % 5 == 0
  end

  def count_frame
    @frames += 1
    return if @frames < 30

    now = Time.now
    @fps.replace strong("#{(@frames / (now - @since)).round} fps", stroke: INK)
    @frames = 0
    @since = now
  end

  def show_counts
    rolling = @marbles.count { |m| m.state == :rolling }
    return if [@settled, rolling] == @shown

    @shown = [@settled, rolling]
    @count.replace @settled.to_s
    @rolling.replace "#{rolling} rolling"
  end

  def on_board?(x, y)
    x.between?(LEFT_WALL, RIGHT_WALL) && y.between?(40, TUBE_TOP - 10)
  end

  # ---- the controls ----

  # A pill-shaped button. Its margins sit inside the size it is given.
  def pill(label, width, fill, text, &on_click)
    button = stack(width: width + 10, height: 50, margin: [0, 0, 10, 10]) do
      background fill, curve: 20
      border rgb(255, 255, 255, 0.12), curve: 20
      para label, align: "center", stroke: text, size: 13, weight: "semibold", margin_top: 12
    end
    button.click(&on_click)
    button
  end

  # A round swatch, or for :rainbow a little pie of every jewel.
  def swatch(choice, color)
    ring = nil
    spot = stack(width: 50, height: 48, margin: [0, 0, 10, 8]) do
      ring = oval 20, 20, 36, center: true, fill: rgb(0, 0, 0, 0), stroke: INK, strokewidth: 2, hidden: true
      if choice == :rainbow
        nostroke
        JEWELS.each_with_index { |jewel, i| slice(20, 20, 13, i, JEWELS.size, jewel) }
      else
        oval 20, 20, 26, center: true, fill: glass(color), stroke: rgb(0, 0, 0, 0)
        oval 16, 15, 6, center: true, fill: rgb(255, 255, 255, 0.7), stroke: rgb(0, 0, 0, 0)
      end
    end
    spot.click { choose(choice) }
    @spots[choice] = spot
    @rings[choice] = ring
  end

  # One slice of a pie of `count`, the first starting at twelve o'clock.
  def slice(x, y, radius, index, count, color)
    turn = 2 * Math::PI / count
    arc x - radius, y - radius, radius * 2, radius * 2, index * turn - Math::PI / 2, (index + 1) * turn - Math::PI / 2,
      wedge: true, fill: rgb(*color)
  end

  def choose(choice)
    @color = choice
    @rings.each { |name, ring| ring.hidden = name != choice }
  end

  # ---- the scene ----

  background "#0e1b27".."#21162f", angle: 25

  # the glass case, with a sheen down its left side
  nostroke
  rect 24, 24, 552, 592, curve: 22, fill: rgb(255, 255, 255, 0.035), stroke: rgb(255, 255, 255, 0.07)
  rect 30, 30, 70, 580, curve: 18, fill: gradient(rgb(255, 255, 255, 0.05), rgb(255, 255, 255, 0), angle: 90)

  # the hopper
  fill gradient(*BRASS, angle: 0)
  shape do
    move_to HOPPER_X - 34, 30
    line_to HOPPER_X + 34, 30
    line_to HOPPER_X + 6, 50
    line_to HOPPER_X + 6, 56
    line_to HOPPER_X - 6, 56
    line_to HOPPER_X - 6, 50
    line_to HOPPER_X - 34, 30
  end
  rect HOPPER_X - 34, 30, 68, 3, fill: rgb(255, 255, 255, 0.35)

  # the tubes: a darker glass behind each, and brass walls between them
  TUBES.times do |i|
    x = LEFT_WALL + i * TUBE_WIDTH
    rect x + 2, TUBE_TOP, TUBE_WIDTH - 4, FLOOR - TUBE_TOP, curve: 4, fill: rgb(0, 0, 0, 0.16)
    rect x + 4, TUBE_TOP + 4, 2, FLOOR - TUBE_TOP - 8, curve: 1, fill: rgb(255, 255, 255, 0.05)
  end
  (0..TUBES).each do |i|
    x = LEFT_WALL + i * TUBE_WIDTH
    rect x - 1.5, TUBE_TOP, 3, FLOOR - TUBE_TOP, fill: gradient(*BRASS, angle: 90)
    oval x, TUBE_TOP, 4, center: true, fill: BRASS.first
  end
  @doors = [
    rect(LEFT_WALL - 2, FLOOR, 262, 7, curve: 3, fill: gradient(*BRASS, angle: 0)),
    rect(LEFT_WALL + 260, FLOOR, 262, 7, curve: 3, fill: gradient(*BRASS, angle: 0)),
  ]

  build_pins
  @hint = para "click anywhere up here to drop a marble", size: 11, stroke: rgb(255, 255, 255, 0.3),
    left: LEFT_WALL + 12, top: 88, width: 230
  # marbles live on two layers: every comet tail under every marble
  @tails = stack(left: 0, top: 0, width: WIDTH, height: HEIGHT) {}
  @glass = stack(left: 0, top: 0, width: WIDTH, height: HEIGHT) {}

  # ---- the panel ----

  @spots = {}
  @rings = {}
  stack left: 612, top: 44, width: 260, height: 560 do
    para "Marble Machine", size: 28, weight: "light", stroke: INK, margin: [0, 0, 0, 4]
    para "Brass pins, glass tubes and a little gravity.", size: 13, stroke: MUTED, margin: [0, 0, 0, 22]

    stack width: 250, height: 132, margin_bottom: 22 do
      background rgb(255, 255, 255, 0.05), curve: 16
      border rgb(255, 255, 255, 0.08), curve: 16
      @count = para "0", size: 44, weight: "light", stroke: INK, margin: [20, 12, 0, 0]
      para "marbles in the tubes", size: 12, stroke: MUTED, margin: [21, 0, 0, 12]
      flow margin: [21, 0, 0, 0] do
        @fps = para strong("-- fps", stroke: INK), size: 12, margin: [0, 0, 14, 0]
        @rolling = para "0 rolling", size: 12, stroke: MUTED, margin: 0
      end
    end

    para "COLOUR", size: 10, weight: "semibold", kerning: 2, stroke: MUTED, margin: [0, 0, 0, 8]
    flow width: 250, margin_bottom: 12 do
      JEWELS.each_with_index { |jewel, i| swatch(i, jewel) }
      swatch(:rainbow, nil)
    end

    flow width: 270 do
      pill("Pour forty", 118, gradient(*BRASS, angle: 0), "#3a2a12") { @pouring += 40 }
      pill("Empty the tubes", 132, rgb(255, 255, 255, 0.08), INK) { empty_tubes }
    end

    para "Click above the tubes to drop a marble. Hold the button and sweep to pour.",
      size: 12, stroke: MUTED, margin: [0, 16, 0, 6]
    para "Space pours forty. E empties.", size: 12, stroke: MUTED, margin: 0
  end

  # ---- state ----

  @marbles = []
  @ripples = []
  @warm = []
  @piles = Array.new(TUBES) { [] }
  @settled = 0
  @door = @door_goal = 0 # the floor: 0 is shut, 1 is open
  @pouring = 24 # a welcome
  @pour_clock = 0
  @stream_clock = 0
  @streaming = false
  @turn = -1
  @frames = 0
  @since = Time.now
  choose(:rainbow)

  click do |button, x, y|
    next unless button == 1 && on_board?(x, y)

    drop_marble(x, y)
    ripple(x, y)
    @hint.hide
    @streaming = true
    @stream_clock = 0
  end
  release { @streaming = false }

  keypress do |key|
    case key
    when " " then @pouring += 40
    when "e", "E" then empty_tubes
    end
  end

  animate(60) do
    pour_tick
    step_world
    @marbles.each { |marble| draw(marble) }
    slide_doors
    spread_ripples
    cool_pins
    show_counts
    count_frame
  end
end
