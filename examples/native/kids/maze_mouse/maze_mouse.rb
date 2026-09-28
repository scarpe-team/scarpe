# Maze Mouse: help a little mouse find the cheese.
#
# A mouse sits at the start of a hand-drawn maze and dreams of cheese. Guide it with
# the arrow keys, or tap the big arrows (or tap the maze beside the mouse), and it
# scurries along, leaving a trail of paw prints. At the cheese there is a nibble, a
# burst of confetti and a happy tune, and then a new maze draws itself, a little
# bigger than the last.
#
# Every maze is made fresh and always has a way through. Bumping into a wall just
# goes "boop", there is no clock, and there is no way to lose. If you listen, the
# mouse's footsteps sing a little higher as it gets closer to the cheese.
#
# Big kid mode (the star switch) starts with bigger mazes and hides stars in the
# corners to collect on the way.
#
# For grown-ups: the arrow keys or W, A, S and D move the mouse, and any other key
# makes it squeak. Hold Escape for two seconds to leave. Nothing is saved and nothing
# is sent anywhere.
#
# The sounds are made right here in plain Ruby: soft notes on a pentatonic scale,
# written once as small WAV files and played with afplay.

require "fileutils"
require "tmpdir"

W, H = 960, 720
PAPER = [24, 88, 724, 612] # the sheet of paper the maze is drawn on: left, top, width, height
ROOM = [52, 116, 668, 556] # the part of the paper a maze may fill
INK = [61, 52, 86]
PENCIL = [96, 76, 64]
# Fredoka, the round font the Kids apps share: in fonts or beside the app once it is packaged,
# and in the _fonts folder next door in a Scarpe checkout. Without it the words still show.
FREDOKA = %w[fonts . _fonts ../_fonts].map { |dir| File.expand_path("#{dir}/Fredoka.ttf", __dir__) }.find { |path| File.exist?(path) }

STEPS = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] }
BACK = { up: :down, down: :up, left: :right, right: :left }
KEYS = { up: :up, down: :down, left: :left, right: :right, "w" => :up, "s" => :down, "a" => :left, "d" => :right }

# How big each maze is, in rooms across and down: one row for each maze, then the
# last one again. Big kids start further down a longer list.
SIZES = [[4, 3], [5, 3], [5, 4], [6, 4], [7, 5], [8, 5], [9, 6], [10, 7], [11, 7], [12, 8]]
BIG_SIZES = [[7, 5], [8, 6], [10, 6], [11, 7], [12, 8], [14, 8], [15, 9]]
STEP_TIME = 0.15 # seconds for one step from room to room
BANNER_X = PAPER[0] + PAPER[2] / 2 - 154
NOTES = %w[c4 d4 e4 g4 a4 c5 d5 e5 g5 a5 c6] # the footsteps climb these as the cheese gets close

# A maze is a grid of rooms, each keeping a list of its ways out.
class Maze
  attr_reader :cols, :rows, :cheese

  def initialize(cols, rows, random)
    @cols, @rows = cols, rows
    @doors = Hash.new { |doors, room| doors[room] = [] }
    dig(random)
    from_start = distances([0, 0])
    @cheese = from_start.max_by { |_, steps| steps }.first # the room furthest from the start
    @to_cheese = distances(@cheese)
  end

  def open?(room, way) = @doors[room].include?(way)
  def ways_out(room) = @doors[room]
  def rooms = (0...@rows).flat_map { |row| (0...@cols).map { |col| [col, row] } }
  def dead_ends = rooms.select { |room| @doors[room].size == 1 }
  def steps_to_cheese(room) = @to_cheese.fetch(room)
  def longest_walk = @to_cheese.values.max

  def next_room(room, way)
    [room[0] + STEPS[way][0], room[1] + STEPS[way][1]]
  end

  # The next few steps from a room towards the cheese: always downhill in steps left.
  def way_to_cheese(room, steps)
    rooms = []
    steps.times do
      break if room == @cheese

      room = next_room(room, @doors[room].min_by { |way| @to_cheese[next_room(room, way)] })
      rooms << room
    end
    rooms
  end

  # The walls as straight runs from corner to corner, [col, row, col, row]: every run
  # along the top of a row, and every run down the left of a column.
  def walls
    across = (0..@rows).flat_map do |row|
      runs((0...@cols).map { |col| row == 0 || row == @rows || !open?([col, row], :up) }).map { |from, to| [from, row, to, row] }
    end
    down = (0..@cols).flat_map do |col|
      runs((0...@rows).map { |row| col == 0 || col == @cols || !open?([col, row], :left) }).map { |from, to| [col, from, col, to] }
    end
    across + down
  end

  private

  # "Recursive backtracking": wander from the start, knocking through into rooms not
  # visited yet; at a dead end, walk back until there is somewhere new to go. Every
  # room is visited, so every room joins up and there is always a way through.
  def dig(random)
    seen = { [0, 0] => true }
    trail = [[0, 0]]
    until trail.empty?
      room = trail.last
      ways = STEPS.keys.select { |way| inside?(next_room(room, way)) && !seen[next_room(room, way)] }
      if ways.empty?
        trail.pop
        next
      end
      way = ways.sample(random: random)
      nxt = next_room(room, way)
      @doors[room] << way
      @doors[nxt] << BACK[way]
      seen[nxt] = true
      trail << nxt
    end
  end

  def inside?(room) = room[0].between?(0, @cols - 1) && room[1].between?(0, @rows - 1)

  # How many steps it takes from `start` to every room: a breadth-first walk.
  def distances(start)
    steps = { start => 0 }
    queue = [start]
    until queue.empty?
      room = queue.shift
      @doors[room].each do |way|
        nxt = next_room(room, way)
        next if steps.key?(nxt)

        steps[nxt] = steps[room] + 1
        queue << nxt
      end
    end
    steps
  end

  # [true, true, false, true] => [[0, 2], [3, 4]]: where each run of walls starts and ends.
  def runs(flags)
    flags.each_with_index.chunk_while { |(a, _), (b, _)| a == b }.select { |run| run.first[0] }
      .map { |run| [run.first[1], run.last[1] + 1] }
  end
end

# The mouse's voice. Each sound is worked out once as numbers, written to a small WAV
# file, and played in the background with afplay while the game carries on.
class Chimes
  RATE = 22_050
  TAU = 2 * Math::PI
  PEAK = 0.25   # the loudest any sound is written: a quarter of full scale
  AT_ONCE = 3   # at most three sounds at a time, so mashing never piles them up
  PITCH = { "c" => 0, "d" => 2, "e" => 4, "f" => 5, "g" => 7, "a" => 9, "b" => 11 }

  attr_reader :last_file, :player
  attr_accessor :muted

  def initialize
    @dir = Dir.mktmpdir("maze-mouse")
    at_exit { FileUtils.rm_rf(@dir) }
    @files = {}
    @notes = {}
    @playing = []
    @muted = false
  end

  # Plays a tune like "c5 e5 g5": one note every `gap` seconds, in one of the voices
  # below, `level` of the way up to the loudest.
  def tune(notes, voice: :bell, gap: 0.14, level: 1.0)
    return if @muted

    @playing.select!(&:alive?)
    return if @playing.size >= AT_ONCE

    name = "#{voice}-#{notes.tr(" ", "-")}-#{(gap * 1000).round}-#{(level * 100).round}"
    @last_file = @files[name] ||= write(name, mix(notes.split, voice, gap, level))
    @player = Process.detach(spawn("afplay", @last_file, out: File::NULL, err: File::NULL))
    @playing << @player
  rescue SystemCallError
    # no afplay here (not a Mac): the mouse scurries in silence
  end

  private

  def mix(notes, voice, gap, level)
    parts = notes.each_with_index.map { |note, i| [(i * gap * RATE).round, @notes[[voice, note]] ||= send(voice, hz(note))] }
    out = Array.new(parts.map { |start, samples| start + samples.size }.max, 0.0)
    parts.each { |start, samples| samples.each_with_index { |sample, i| out[start + i] += sample } }
    loudest = out.map(&:abs).max
    out.map { |sample| sample * PEAK * level / loudest }
  end

  # A music box: a warm sine with two soft overtones, fading like a plucked tine.
  def bell(hz)
    sound(1.2) do |t|
      (Math.sin(TAU * hz * t) + 0.22 * Math.sin(TAU * 2 * hz * t) * Math.exp(-t * 6) +
        0.07 * Math.sin(TAU * 3 * hz * t) * Math.exp(-t * 10)) * Math.exp(-t * 3.4)
    end
  end

  # A footstep: a short, round note like a soft xylophone.
  def pip(hz)
    sound(0.2) { |t| (Math.sin(TAU * hz * t) + 0.15 * Math.sin(TAU * 4 * hz * t) * Math.exp(-t * 40)) * Math.exp(-t * 22) }
  end

  # Bumping a wall: a low, soft triangle that sags a little, like a cushion.
  def boop(hz)
    phase = 0.0
    sound(0.22) do |t|
      phase += hz * (1 - 0.25 * t / 0.22) / RATE
      (2 * (2 * (phase % 1) - 1).abs - 1) * Math.exp(-t * 14)
    end
  end

  # A squeak: a quick sine that slides up.
  def squeak(hz)
    phase = 0.0
    sound(0.12) do |t|
      phase += hz * (1 + 0.5 * t / 0.12) / RATE
      Math.sin(TAU * phase) * Math.sin(Math::PI * t / 0.12)
    end
  end

  # `seconds` of sound, with a soft start and a gentle last fade, so nothing clicks.
  def sound(seconds)
    count = (RATE * seconds).round
    Array.new(count) do |i|
      yield(i.fdiv(RATE)) * [i / (0.008 * RATE), 1, (count - i) / (0.03 * RATE)].min
    end
  end

  # "a4" is 440 Hz, and each semitone up is the twelfth root of two higher.
  def hz(note)
    440 * 2**((PITCH.fetch(note[0]) + 12 * (note[1..].to_i + 1) - 69) / 12.0)
  end

  # A WAV file is a 44-byte header, then every sample as a 16-bit number.
  def write(name, samples)
    data = samples.map { |sample| (sample * 32_767).round }.pack("s<*")
    header = ["RIFF", 36 + data.bytesize, "WAVE", "fmt ", 16, 1, 1, RATE, RATE * 2, 2, 16, "data", data.bytesize]
    path = File.join(@dir, "#{name}.wav")
    File.binwrite(path, header.pack("a4Va4a4VvvVVvva4V") + data)
    path
  end
end

# A spring makes things bounce: kick it, and it wobbles back to rest.
class Spring
  attr_reader :at

  def initialize(stiffness: 320, damping: 13)
    @stiffness, @damping = stiffness, damping
    @at = @speed = 0.0
  end

  def kick(speed) = @speed += speed
  def still? = @at.abs < 0.1 && @speed.abs < 1

  def step(dt)
    @speed += (-@stiffness * @at - @damping * @speed) * dt
    @at += @speed * dt
    @at = @speed = 0.0 if still?
    @at
  end
end

font FREDOKA if FREDOKA

Shoes.app(title: "Maze Mouse", width: W, height: H, resizable: false) do
  # ---- small helpers ----

  def paint(color, alpha = 1.0) = rgb(*color.map(&:round), alpha)
  def ease(p) = p < 0.5 ? 2 * p * p : 1 - (-2 * p + 2)**2 / 2

  # The middle of a room, in window pixels.
  def middle(room)
    [@left + (room[0] + 0.5) * @cell, @top + (room[1] + 0.5) * @cell]
  end

  # ---- the room around the paper ----

  def room
    background paint([226, 244, 240])..paint([238, 232, 255])
    nostroke
    oval 930, 700, 120, center: true, fill: paint([180, 220, 255], 0.3)
    x, y, w, h = PAPER
    4.times { |i| rect x - i, y + 4 + i, w + i * 2, h, curve: 18 + i, fill: paint(INK, 0.04) }
    rect x, y, w, h, curve: 18, fill: paint([255, 252, 242])..paint([252, 245, 228])
    # faint squares, like graph paper
    ((x + 24)...(x + w)).step(24) { |gx| rect gx, y + 10, 1, h - 20, fill: paint([120, 170, 220], 0.12) }
    ((y + 24)...(y + h)).step(24) { |gy| rect x + 10, gy, w - 20, 1, fill: paint([120, 170, 220], 0.12) }
  end

  # ---- drawing a maze ----

  # A pencil line: a few points a little off the straight, so it looks drawn by hand.
  def pencil(x1, y1, x2, y2, width, random)
    length = Math.hypot(x2 - x1, y2 - y1)
    pieces = [(length / 22).ceil, 1].max
    nx, ny = -(y2 - y1) / length, (x2 - x1) / length
    points = (0..pieces).map do |i|
      wobble = i.zero? || i == pieces ? 0 : random.rand(-1.6..1.6)
      [x1 + (x2 - x1) * i / pieces + nx * wobble, y1 + (y2 - y1) * i / pieces + ny * wobble]
    end
    nofill
    shape(stroke: paint(PENCIL), strokewidth: width, cap: :round, hidden: true) do
      move_to(*points.first)
      points.drop(1).each { |x, y| line_to x, y }
    end
  end

  def draw_maze
    cols, rows = @maze.cols, @maze.rows
    @cell = [[ROOM[2] / cols, ROOM[3] / rows].min, 118].min.floor
    @left = ROOM[0] + (ROOM[2] - cols * @cell) / 2
    @top = ROOM[1] + (ROOM[3] - rows * @cell) / 2
    random = Random.new(@seed)
    width = [@cell * 0.085, 4].max
    @walls = []
    @maze_layer.clear do
      home
      @walls = @maze.walls.sort_by { |c1, r1, _, _| c1 + r1 }.map do |c1, r1, c2, r2|
        pencil(@left + c1 * @cell, @top + r1 * @cell, @left + c2 * @cell, @top + r2 * @cell, width, random)
      end
      draw_stars
      @cheese_art = stack(left: 0, top: 0, width: @cell, height: @cell, hidden: true) { cheese_art(@cell) }
    end
    @paws.clear
    @reveal = 0.0
  end

  # A little arched mouse hole in the corner of the first room: home.
  def home
    x, y = middle([0, 0])
    s = @cell
    arch = lambda do |grow|
      proc do
        move_to x - s * (0.3 + grow), y + s * 0.4
        line_to x - s * (0.3 + grow), y + s * 0.08
        curve_to x - s * (0.3 + grow), y - s * (0.22 + grow), x + s * (0.22 + grow), y - s * (0.22 + grow), x + s * (0.22 + grow), y + s * 0.08
        line_to x + s * (0.22 + grow), y + s * 0.4
        line_to x - s * (0.3 + grow), y + s * 0.4
      end
    end
    nostroke
    shape(fill: paint([196, 150, 110], 0.55), &arch.(0.06))
    shape(fill: paint([88, 64, 52], 0.5), &arch.(0))
  end

  # A wedge of cheese with holes in it, in a box `s` wide.
  def cheese_art(s)
    nostroke
    oval s * 0.5, s * 0.8, s * 0.74, s * 0.12, center: true, fill: paint([150, 110, 40], 0.18)
    shape(fill: paint([255, 214, 90]), stroke: paint([214, 150, 30]), strokewidth: [s * 0.03, 2].max) do
      move_to s * 0.14, s * 0.76
      line_to s * 0.88, s * 0.76
      line_to s * 0.88, s * 0.34
      line_to s * 0.14, s * 0.76
    end
    shape(fill: paint([255, 232, 140]), stroke: paint([214, 150, 30]), strokewidth: [s * 0.03, 2].max) do
      move_to s * 0.14, s * 0.76
      line_to s * 0.88, s * 0.34
      line_to s * 0.78, s * 0.24
      line_to s * 0.06, s * 0.66
      line_to s * 0.14, s * 0.76
    end
    [[0.66, 0.6, 0.12], [0.8, 0.5, 0.07], [0.5, 0.68, 0.07], [0.76, 0.68, 0.06]].each do |x, y, d|
      oval s * x, s * y, s * d, center: true, fill: paint([232, 172, 46])
    end
    oval s * 0.3, s * 0.54, s * 0.07, s * 0.035, center: true, fill: paint([255, 255, 255], 0.7)
  end

  def draw_stars
    @stars = []
    return unless @big_kid

    count = [3 + @level / 2, 7].min
    spots = (@maze.dead_ends - [[0, 0], @maze.cheese]).shuffle(random: Random.new(@seed + 1))
    spots += (@maze.rooms - spots - [[0, 0], @maze.cheese]).shuffle(random: Random.new(@seed + 2))
    transform :center # so a star turns about its own middle
    @stars = spots.first(count).map do |room|
      x, y = middle(room)
      glow = oval(x, y, @cell * 0.62, center: true, fill: paint([255, 220, 90], 0.25), hidden: true)
      art = star(x, y, 5, @cell * 0.26, @cell * 0.12, fill: paint([255, 200, 40]), stroke: paint([220, 150, 20]), strokewidth: 2, hidden: true)
      { room: room, art: art, glow: glow, turn: rand * 360 }
    end
  end

  # ---- the mouse ----

  # The mouse is drawn facing right in a box 120 by 100 "mouse units", `k` pixels
  # each; facing left, every x is mirrored.
  def mouse_art(k, facing)
    mx = ->(x) { facing > 0 ? (x + 10) * k : (110 - x) * k }
    at = ->(x, y) { [mx.(x), y * k] }
    fur, pink, ear = [184, 178, 200], [250, 164, 186], [214, 206, 226]
    edge = paint([112, 102, 132])
    nostroke
    oval mx.(50), 88 * k, 70 * k, 10 * k, center: true, fill: paint(INK, 0.12)
    strokewidth 4 * k
    shape(stroke: paint(pink), cap: :round) do
      move_to(*at.(22, 66))
      curve_to(*at.(8, 70), *at.(-4, 58), *at.(2, 44))
      curve_to(*at.(6, 34), *at.(14, 38), *at.(10, 44))
    end
    nostroke
    [[38, 82], [60, 82]].each { |x, y| oval mx.(x), y * k, 13 * k, 8 * k, center: true, fill: paint(pink) }
    oval mx.(46), 62 * k, 62 * k, 42 * k, center: true, fill: paint(fur), stroke: edge, strokewidth: 2
    oval mx.(48), 69 * k, 42 * k, 22 * k, center: true, fill: paint([232, 228, 240])
    oval mx.(60), 30 * k, 28 * k, center: true, fill: paint(ear), stroke: edge, strokewidth: 2
    oval mx.(60), 31 * k, 17 * k, center: true, fill: paint(pink)
    oval mx.(72), 50 * k, 44 * k, 38 * k, center: true, fill: paint(fur), stroke: edge, strokewidth: 2
    oval mx.(90), 56 * k, 20 * k, 15 * k, center: true, fill: paint(fur)
    oval mx.(76), 26 * k, 32 * k, center: true, fill: paint(ear), stroke: edge, strokewidth: 2
    oval mx.(76), 27 * k, 20 * k, center: true, fill: paint(pink)
    oval mx.(98), 54 * k, 10 * k, 9 * k, center: true, fill: paint([236, 110, 140])
    oval mx.(79), 59 * k, 10 * k, 6 * k, center: true, fill: paint(pink, 0.6)
    eye = [oval(mx.(82), 46 * k, 8 * k, 10 * k, center: true, fill: paint(INK)),
      oval(mx.(83.5), 44 * k, 3 * k, center: true, fill: white)]
    happy = shape(stroke: paint(INK), strokewidth: 2.5 * k, cap: :round, hidden: true) do
      move_to(*at.(77, 48))
      curve_to(*at.(79, 42), *at.(85, 42), *at.(87, 48))
    end
    strokewidth [1.2 * k, 1].max
    [50, 58, 66].each { |y| line mx.(94), 57 * k, mx.(110), y * k, stroke: paint([122, 112, 140], 0.8) }
    { eye: eye, happy: happy }
  end

  def draw_mouse
    k = @cell * 0.82 / 100
    @mouse_k = k
    @mouse_slot.clear { @mouse_parts = mouse_art(k, @facing) }
    @mouse_slot.style(width: 120 * k, height: 100 * k)
    place_mouse(*middle(@at))
  end

  def place_mouse(x, y, lift = 0)
    k = @mouse_k
    @mouse_slot.move((x - 60 * k).round(1), (y - 58 * k - lift).round(1))
  end

  def face(way)
    turn = way == :left ? -1 : way == :right ? 1 : @facing
    return if turn == @facing

    @facing = turn
    draw_mouse
  end

  def happy_face(happy)
    @mouse_parts[:eye].each { |part| part.hidden = happy }
    @mouse_parts[:happy].hidden = !happy
  end

  # ---- moving ----

  def go(way)
    @busy_at = @t
    forget_help
    return squeak unless @state == :playing

    @queue << way if @queue.size < 2
    step_on unless @moving
  end

  def step_on
    way = @queue.shift or return
    wake_up # it knows where it is going now
    face(way)
    if @maze.open?(@at, way)
      from = @at
      @at = @maze.next_room(@at, way)
      @moving = { from: from, to: @at, way: way, age: 0.0 }
      @paws.append { paw_prints(from, @at, way) }
      @chimes.tune(footstep(@at), voice: :pip, level: 0.6)
    else
      @moving = { from: @at, to: @at, way: way, age: 0.0, bump: true }
      @chimes.tune("e3", voice: :boop, level: 0.7)
    end
  end

  # Each footstep is a note, climbing the scale as the cheese gets near.
  def footstep(room)
    near = 1 - @maze.steps_to_cheese(room).fdiv([@maze.longest_walk, 1].max)
    NOTES[(near * (NOTES.size - 1)).round]
  end

  def walk(dt)
    return unless @moving

    move = @moving
    move[:age] += dt / STEP_TIME
    p = [move[:age], 1].min
    (x1, y1), (x2, y2) = middle(move[:from]), middle(move[:to])
    if move[:bump]
      dx, dy = STEPS[move[:way]]
      nudge = Math.sin(Math::PI * p) * @cell * 0.16
      place_mouse(x1 + dx * nudge, y1 + dy * nudge)
    else
      e = ease(p)
      place_mouse(x1 + (x2 - x1) * e, y1 + (y2 - y1) * e, Math.sin(Math::PI * p) * @cell * 0.06)
    end
    return if p < 1

    @moving = nil
    arrived
  end

  def arrived
    pick_up_star
    return found_cheese if @at == @maze.cheese

    step_on
  end

  # Two little prints for each step, one each side, between one room and the next.
  def paw_prints(from, to, way, color = [226, 140, 160], alpha = 0.5, grow = 1.0)
    (x1, y1), (x2, y2) = middle(from), middle(to)
    dx, dy = STEPS[way]
    size = @cell * 0.13 * grow
    nostroke
    [[0.3, 1], [0.7, -1]].each do |along, side|
      x = x1 + (x2 - x1) * along - dy * size * 0.7 * side
      y = y1 + (y2 - y1) * along + dx * size * 0.7 * side
      oval x, y, size * 1.1, size, center: true, fill: paint(color, alpha)
      [-0.6, 0, 0.6].each do |spread|
        oval x + dx * size * 0.95 - dy * size * spread, y + dy * size * 0.95 + dx * size * spread, size * 0.42,
          center: true, fill: paint(color, alpha)
      end
    end
  end

  def pick_up_star
    got = @stars.find { |one| one[:room] == @at && !one[:taken] }
    return unless got

    got[:taken] = true
    got[:art].hide
    got[:glow].hide
    x, y = middle(@at)
    10.times { |i| confetti(x, y, i * Math::PI / 5, [255, 210, 70]) }
    taken = @stars.count { |one| one[:taken] }
    @chimes.tune("g5 #{%w[c6 d6 e6 g6 a6][[taken - 1, 4].min]}", gap: 0.08, level: 0.7)
    show_star_count
  end

  def found_cheese
    @state = :celebrating
    @eaten += 1
    @cheese_count.replace @eaten.to_s
    @counter_spring.kick(-300)
    all_stars = @big_kid && @stars.all? { |one| one[:taken] }
    happy_face(true)
    @hop.kick(-420)
    x, y = middle(@at)
    48.times { |i| confetti(x, y, i * Math::PI / 24) }
    8.times { |i| confetti(x, y, -Math::PI / 2 + (i - 3.5) * 0.3, [255, 214, 90]) } # crumbs
    @chimes.tune(all_stars ? "c5 e5 g5 c6 e6 g6" : "c5 e5 g5 c6", gap: 0.11)
    timer(0.55) { @chimes.tune("e6 c6 e6", voice: :pip, gap: 0.09, level: 0.6) }
    @banner_text.replace(all_stars ? "Every star!" : "Yum!")
    @banner.show
    @banner_spring.kick(-500)
    @cheese_art.hide
    eaten = @maze
    timer(2.6) { next_maze if @maze.equal?(eaten) } # unless big kid mode has already made a new one
  end

  def next_maze
    @banner.hide
    @level += 1
    new_maze
  end

  # ---- a new maze: it draws itself, then the mouse pops out of its hole ----

  def new_maze
    @seed = @random.rand(1_000_000)
    cols, rows = (@big_kid ? BIG_SIZES : SIZES).then { |sizes| sizes[[@level - 1, sizes.size - 1].min] }
    @maze = Maze.new(cols, rows, Random.new(@seed))
    @at = [0, 0]
    @facing = 1
    @queue = []
    @moving = nil
    @state = :drawing
    wake_up
    forget_help
    @busy_at = @t
    draw_maze
    draw_mouse
    @mouse_slot.hide
    @level_label.replace "Maze #{@level}"
    show_star_count
    @chimes.tune("c5 d5 e5 g5 a5 c6", gap: 0.07, level: 0.5)
  end

  # The walls appear in a sweep from the top left, then the cheese and stars.
  def draw_in(dt)
    return unless @reveal

    before = (@walls.size * @reveal).floor
    @reveal += dt / 0.8
    after = [(@walls.size * @reveal).floor, @walls.size].min
    @walls[before...after].each(&:show)
    return if @reveal < 1

    @reveal = nil
    @walls.each(&:show)
    x, y = middle(@maze.cheese)
    @cheese_art.move((x - @cell / 2).round(1), (y - @cell / 2).round(1))
    @cheese_art.show
    @stars.each { |one| [one[:art], one[:glow]].each(&:show) }
    @mouse_slot.show
    happy_face(false)
    @hop.kick(-300)
    @state = :playing
    dream
    @chimes.tune("g5 c6", voice: :squeak, gap: 0.1, level: 0.5)
  end

  # For a moment the mouse thinks of cheese: that is where it wants to go.
  def dream
    x, y = middle([0, 0])
    @dream.move((x + @cell * 0.2).round, (y - @cell * 0.5 - 70).round)
    @dream.show
    @dream_until = @t + 2.2
  end

  def wake_up
    @dream.hide if @dream_until
    @dream_until = nil
  end

  # Stuck? After ten quiet seconds the mouse thinks of cheese again, and faint golden
  # prints show the next three steps. They go as soon as it moves.
  def help_if_stuck
    return unless @state == :playing && !@moving && @t - @busy_at > 10 && !@helping

    @helping = true
    dream
    room = @at
    @help_layer.clear do
      @maze.way_to_cheese(@at, 3).each_with_index do |nxt, i|
        way = STEPS.keys.find { |one| @maze.next_room(room, one) == nxt }
        paw_prints(room, nxt, way, [245, 170, 30], 0.7 - i * 0.15, 1.4) # bigger as well as golden, not told apart by colour alone
        room = nxt
      end
    end
  end

  def forget_help
    return unless @helping

    @helping = false
    @help_layer.clear
  end

  # ---- things that bounce, twinkle and fly ----

  def confetti(x, y, angle, color = nil)
    bit = @confetti.find { |one| one[:age] >= 1 } || @confetti.max_by { |one| one[:age] }
    speed = rand(160.0..380.0)
    color ||= [[255, 107, 107], [255, 196, 87], [72, 199, 142], [84, 160, 255], [178, 128, 255], [255, 140, 200]].sample
    bit.merge!(x: x, y: y, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed - 180, age: 0.0, spin: rand(-400.0..400.0), color: color)
    bit[:art].style(fill: paint(color), hidden: false)
  end

  def move_confetti(dt)
    @confetti.each do |bit|
      next if bit[:age] >= 1

      bit[:age] += dt / 1.6
      bit[:vy] += 520 * dt
      bit[:vx] *= 0.985
      bit[:x] += bit[:vx] * dt
      bit[:y] += bit[:vy] * dt
      done = bit[:age] >= 1 || bit[:y] > H
      bit[:age] = 1 if done
      bit[:art].style(left: bit[:x].round(1), top: bit[:y].round(1), rotate: (bit[:spin] * bit[:age]).round, hidden: done)
    end
  end

  def bounce(dt)
    unless @hop.still? && !@hopping
      lift = -@hop.step(dt) * 0.12
      place_mouse(*middle(@at), lift) unless @moving
    end
    @hopping = !@hop.still?
    @banner.move(BANNER_X, (300 + @banner_spring.step(dt) * 0.2).round(1)) unless @banner_spring.still? && !@banner_moving
    @banner_moving = !@banner_spring.still?
    @counter.move(790, (170 + @counter_spring.step(dt) * 0.1).round(1)) unless @counter_spring.still? && !@counter_moving
    @counter_moving = !@counter_spring.still?
    @pads.each do |pad|
      next if pad[:spring].still? && !pad[:moving]

      pad[:slot].move(pad[:x], (pad[:y] + pad[:spring].step(dt) * 0.4).round(1))
      pad[:moving] = !pad[:spring].still?
    end
  end

  # Stars turn slowly and the cheese breathes, so the goal always looks alive.
  def twinkle(frame)
    @stars.each_with_index do |one, i|
      next if one[:taken] || frame.odd?

      one[:art].style(rotate: ((@t * 40 + one[:turn]) % 72).round(1)) # a five-pointed star looks the same every 72 degrees
      glow = (@cell * (0.58 + 0.08 * Math.sin(@t * 2.4 + i))).round(1)
      one[:glow].style(width: glow, height: glow)
    end
    return unless @state == :playing

    bob = (middle(@maze.cheese)[1] - @cell / 2 - 2 - 2 * Math.sin(@t * 3)).round
    @cheese_art.style(top: bob) unless bob == @cheese_bob
    @cheese_bob = bob
    blink
    wake_up if @dream_until && @t > @dream_until
  end

  def blink
    if @t >= @blink_at
      @mouse_parts[:eye][0].style(height: 2 * @mouse_k)
      @blink_at = @t + rand(2.0..5.0)
      @open_at = @t + 0.12
    elsif @open_at && @t >= @open_at
      @mouse_parts[:eye][0].style(height: 10 * @mouse_k)
      @open_at = nil
    end
  end

  def squeak
    @hop.kick(-200) if @state == :playing && !@moving
    @chimes.tune(%w[c6 e6 g6 a6].sample, voice: :squeak, level: 0.45)
  end

  # ---- the side panel: sound, big kid mode, cheese eaten, stars, and the arrows ----

  def panel
    # the sound switch
    nostroke
    oval 912, 42, 58, center: true, fill: paint(INK, 0.1)
    oval 912, 38, 58, center: true, fill: white
    fill paint(INK)
    rect 895, 31, 9, 15, curve: 2
    shape { move_to 900, 31; line_to 911, 23; line_to 911, 54; line_to 900, 46; line_to 900, 31 }
    nofill
    strokewidth 3.2
    @waves = [arc(909, 30, 18, 18, -0.9, 0.9, stroke: paint(INK), cap: :round), arc(905, 23, 31, 31, -0.8, 0.8, stroke: paint(INK), cap: :round)]
    @hush = [line(916, 31, 927, 45, stroke: paint(INK), cap: :round, hidden: true), line(927, 31, 916, 45, stroke: paint(INK), cap: :round, hidden: true)]
    nostroke
    oval(912, 38, 62, center: true, fill: rgb(0, 0, 0, 0)).click { toggle_sound }

    # big kid mode: a switch with a star on its knob
    @track = rect 772, 100, 96, 48, curve: 24, fill: paint([214, 210, 226])
    @knob = stack(left: 776, top: 104, width: 40, height: 40) do
      oval 20, 20, 40, center: true, fill: white
      @knob_star = star 20, 20, 5, 13, 6, fill: paint([255, 255, 255]), stroke: paint([200, 190, 215]), strokewidth: 2
    end
    para "Big kid", font: "Fredoka", size: 15, weight: 500, stroke: paint(INK, 0.75), left: 876, top: 112
    rect(768, 92, 176, 64, fill: rgb(0, 0, 0, 0)).click { toggle_big_kid }

    # cheese eaten, and stars (in big kid mode)
    @counter = stack(left: 790, top: 170, width: 160, height: 80) do
      cheese_art(70)
      @cheese_count = para "0", font: "Fredoka", size: 40, weight: 600, stroke: paint(INK), left: 78, top: 6
    end
    @star_counter = stack(left: 790, top: 256, width: 160, height: 60, hidden: true) do
      star 35, 30, 5, 22, 10, fill: paint([255, 200, 40]), stroke: paint([220, 150, 20]), strokewidth: 2
      @star_count = para "0/0", font: "Fredoka", size: 26, weight: 600, stroke: paint(INK), left: 70, top: 10
    end

    # the arrows, in a cross like a game pad
    @pads = []
    { up: [818, 450], left: [750, 530], right: [886, 530], down: [818, 610] }.each do |way, (x, y)|
      pad = { x: x, y: y, spring: Spring.new(stiffness: 500, damping: 18) }
      pad[:slot] = stack(left: x, top: y, width: 70, height: 70) { arrow_pad(way) }
      pad[:slot].click do
        pad[:spring].kick(160)
        go(way)
      end
      @pads << pad
    end
  end

  def arrow_pad(way)
    nostroke
    rect 2, 6, 66, 64, curve: 18, fill: paint([40, 120, 130], 0.35)
    rect 2, 2, 66, 64, curve: 18, fill: paint([96, 196, 204])..paint([64, 170, 182])
    rect 10, 7, 50, 14, curve: 7, fill: paint([255, 255, 255], 0.25)
    angle = { right: 0, down: Math::PI / 2, left: Math::PI, up: -Math::PI / 2 }[way]
    tip = ->(a, r) { [35 + Math.cos(angle + a) * r, 34 + Math.sin(angle + a) * r] }
    shape(fill: white) do
      move_to(*tip.(0, 20))
      line_to(*tip.(2.3, 18))
      line_to(*tip.(-2.3, 18))
      line_to(*tip.(0, 20))
    end
  end

  def toggle_big_kid
    @big_kid = !@big_kid
    @track.fill = @big_kid ? paint([255, 196, 60])..paint([245, 160, 40]) : paint([214, 210, 226])
    @knob.move(@big_kid ? 824 : 776, 104)
    @knob_star.style(fill: paint(@big_kid ? [255, 200, 40] : [255, 255, 255]), stroke: paint(@big_kid ? [220, 150, 20] : [200, 190, 215]))
    @chimes.tune(@big_kid ? "c5 g5 c6" : "c6 g5 c5", gap: 0.08, level: 0.6)
    @banner.hide
    new_maze
  end

  def show_star_count
    @star_counter.hidden = !@big_kid
    @star_count.replace("#{@stars.count { |one| one[:taken] }}/#{@stars.size}") if @big_kid
  end

  def toggle_sound
    @chimes.muted = !@chimes.muted
    @waves.each { |wave| wave.hidden = @chimes.muted }
    @hush.each { |line| line.hidden = !@chimes.muted }
    @chimes.tune("c5 g5", gap: 0.1, level: 0.6) unless @chimes.muted
  end

  # ---- the way out, for grown-ups: hold Escape for two seconds ----

  def hold_escape
    @escape_from = @t if @escape_from.nil? || @t - @escape_last > 0.7
    @escape_last = @t
  end

  def watch_escape
    return unless @escape_from

    held = @escape_last - @escape_from
    if @t - @escape_last > 0.7
      @escape_from = nil
      @leaving.hide
      @hint.replace "hold esc to leave"
    elsif held >= 2
      say_goodbye
    else
      @leaving.style(angle2: -Math::PI / 2 + 2 * Math::PI * held / 2, hidden: false)
      @hint.replace "keep holding to leave"
    end
  end

  def say_goodbye
    close
  end

  # ---- taps and keys ----

  # A tap on the maze moves the mouse one step towards it.
  def tap_maze(x, y)
    return unless @state == :playing

    mx, my = middle(@at)
    dx, dy = x - mx, y - my
    return squeak if dx.abs < @cell * 0.4 && dy.abs < @cell * 0.4

    go(dx.abs > dy.abs ? (dx > 0 ? :right : :left) : (dy > 0 ? :down : :up))
  end

  def key(key)
    return hold_escape if key == :escape

    @escape_from = nil
    way = KEYS[key.is_a?(String) ? key.downcase : key]
    way ? go(way) : squeak
  end

  # ---- building it ----

  @t = 0.0
  @busy_at = 0.0
  @blink_at = 2.0
  @random = Random.new
  @level = 1
  @eaten = 0
  @big_kid = false
  @stars = []
  @chimes = Chimes.new
  @hop = Spring.new(stiffness: 300, damping: 12)
  @banner_spring = Spring.new(stiffness: 260, damping: 11)
  @counter_spring = Spring.new(stiffness: 300, damping: 12)

  room
  title = [[229, 57, 53], [255, 138, 30], [236, 176, 20], [67, 178, 88], [47, 128, 237], [142, 76, 196]]
  para(*"Maze Mouse".chars.each_with_index.map { |letter, i| span(letter, stroke: paint(title[i % 6])) },
    font: "Fredoka", size: 30, weight: 600, left: 30, top: 22)
  @level_label = para "Maze 1", font: "Fredoka", size: 20, weight: 500, stroke: paint(INK, 0.55), left: 236, top: 34
  @maze_layer = stack(left: 0, top: 0, width: W, height: H) {}
  @paws = stack(left: 0, top: 0, width: W, height: H) {}
  @help_layer = stack(left: 0, top: 0, width: W, height: H) {}
  @mouse_slot = stack(left: 0, top: 0, width: 100, height: 100) {}
  @dream = stack(left: 0, top: 0, width: 110, height: 90, hidden: true) do
    nostroke
    [[18, 80, 10], [30, 68, 15]].each { |x, y, d| oval x, y, d, center: true, fill: white, stroke: paint(INK, 0.15), strokewidth: 2 }
    [[50, 34, 46], [74, 30, 50], [92, 42, 34], [60, 50, 40], [82, 52, 36]].each { |x, y, d| oval x, y, d, center: true, fill: white }
    stack(left: 46, top: 12, width: 50, height: 50) { cheese_art(50) }
  end
  @confetti = Array.new(60) { |i| { art: i.even? ? rect(0, 0, 12, 7, curve: 2, hidden: true) : oval(0, 0, 9, hidden: true), age: 1.0 } }
  @banner = stack(left: BANNER_X, top: 300, width: 320, height: 110, hidden: true) do
    nostroke
    rect 6, 10, 308, 96, curve: 32, fill: paint(INK, 0.14)
    rect 0, 0, 308, 96, curve: 32, fill: white, stroke: paint([255, 214, 90]), strokewidth: 5
    @banner_text = para "Yum!", font: "Fredoka", size: 44, weight: 600, stroke: paint([214, 120, 20]), align: "center", width: 308, margin: [0, 16, 0, 0]
  end
  panel
  @hint = para "hold esc to leave", size: 10, stroke: paint(INK, 0.45), left: 40, top: 702
  nofill
  @leaving = arc 20, 702, 14, 14, -Math::PI / 2, -Math::PI / 2, stroke: paint(INK, 0.6), strokewidth: 3, hidden: true

  new_maze

  click do |_button, x, y|
    tap_maze(x, y) if x.between?(PAPER[0], PAPER[0] + PAPER[2]) && y.between?(PAPER[1], PAPER[1] + PAPER[3])
  end

  keypress { |key| key(key) }

  animate(60) do |frame|
    dt = 1 / 60.0
    @t += dt
    draw_in(dt)
    walk(dt)
    bounce(dt)
    move_confetti(dt)
    twinkle(frame)
    help_if_stuck
    watch_escape
  end
end
