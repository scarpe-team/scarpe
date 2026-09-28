# Bubble Garden: blow soap bubbles, and watch them turn into flowers.
#
# Hold the mouse button down, or any key, to blow bubbles. Each one wobbles up
# with a rainbow sheen, then pops, and a seed falls into the grass and grows
# into a flower with a little face. Keys on the left of the keyboard blow big
# bubbles with low notes, keys on the right blow small ones with high notes,
# and each note has its own colour and its own kind of flower. Butterflies come
# to visit as the garden fills up, and then a rainbow comes out.
#
# It is made for little ones from two years old: every key, click and wiggle
# does something, nothing needs reading, nothing can go wrong, and nothing
# flashes. The speaker in the corner turns the sound off. A grown-up can hold
# Escape for two seconds to leave (Cmd-Q works too).
#
# The sounds are made right here in Ruby: soft tones on a pentatonic scale, so
# any bubbles together sound sweet. Each is worked out once, written to a
# little WAV file and played with afplay.

require "fileutils"
require "tmpdir"

W, H = 960, 640
FPS = 30
MOST_BUBBLES = 30 # any more and the oldest pops early, so mashing never slows the garden down

# The notes, low to high: C major pentatonic, which has no wrong notes in it.
NOTES = %w[c4 d4 e4 g4 a4 c5 d5 e5 g5 a5 c6]

# Each note has its own colour and its own kind of flower, so a C is always a
# pink blossom and an A is always a purple daisy. The shapes differ as well as
# the colours, so the flowers can be told apart without seeing colour.
FLOWERS = {
  "c" => { kind: :blossom, petals: ["#ffd0df", "#ff6f9c"], middle: ["#fff3a3", "#ffc93c"] },
  "d" => { kind: :sunny, petals: ["#ffdcae", "#ff8c1a"], middle: ["#fff0b3", "#ffc53d"] },
  "e" => { kind: :tulip, petals: ["#fff5a8", "#fcc419"], middle: nil },
  "g" => { kind: :puff, petals: ["#c3e7ff", "#3d9cf0"], middle: ["#e0f3ff", "#86c9fa"] },
  "a" => { kind: :daisy, petals: ["#f1eaff", "#a98bfa"], middle: ["#fff3a3", "#ffc93c"] },
}

# Where the keys sit on a keyboard, so the left of it blows bubbles on the left.
KEY_ROWS = ["1234567890-=", "qwertyuiop[]", "asdfghjkl;'", "zxcvbnm,./"]

# Three flower beds, back to front: how far down the meadow each one is, and
# how big its flowers grow. Each has fourteen spots for flowers.
BEDS = [{ y: 526, scale: 0.8 }, { y: 580, scale: 0.94 }, { y: 634, scale: 1.08 }]

INK = "#3d2b1f" # eyes and smiles
RAINBOW = %w[#ff8787 #ffc078 #ffe066 #8ce99a #74c0fc #b197fc]

Bubble = Struct.new(:x, :y, :vx, :vy, :size, :note, :age, :life, :phase, :slot, :body, keyword_init: true)
Seed = Struct.new(:x, :y, :vy, :age, :note, :art, keyword_init: true)
Bit = Struct.new(:art, :x, :y, :vx, :vy, :age, :life, :gravity, :color, keyword_init: true)
Flower = Struct.new(:spot, :note, :x, :base, :height, :radius, :box, :stem, :leaves, :head,
  :eyes, :shut, :grow, :phase, :hop, :stir, :chimed, :blink, :shown, keyword_init: true)
Butterfly = Struct.new(:x, :y, :flower, :state, :wait, :phase, :slot, :wings, :visits, :spin, keyword_init: true)
Cloud = Struct.new(:slot, :x, :y, :speed, :width, :bounce, :asleep, :awake, :shown, keyword_init: true)

# ---------------------------------------------------------------- the sound

# A tiny synthesizer. Each sound is a list of numbers worked out once, written
# to a WAV file, and played by afplay in the background while the garden goes on.
class GardenSounds
  RATE = 22_050
  LOUDEST = 0.25 # no sound ever goes above a quarter of full scale
  NAMES = %w[c c# d d# e f f# g g# a a# b]

  attr_reader :last_file, :player
  attr_accessor :muted

  def initialize
    @dir = Dir.mktmpdir("bubble-garden")
    at_exit { FileUtils.rm_rf(@dir) } # the sounds are only kept while the app runs
    @files = {}
    @started = [] # when recent sounds began, in seconds of garden time
  end

  # Plays one sound, unless the sound is off or eight have started in the last
  # second: however fast the keys go, the garden never gets noisy.
  def play(name, note, now)
    return if muted

    @started.reject! { |at| now - at >= 1 }
    return if @started.size >= 8

    @started << now
    @last_file = @files[[name, note]] ||= write("#{name}-#{note}", samples(name, note))
    @player = Process.detach(spawn("afplay", @last_file, out: File::NULL, err: File::NULL))
  rescue SystemCallError
    # no afplay here (not a Mac): the garden grows in silence
  end

  def samples(name, note)
    hz = frequency(note)
    case name
    when :blow then blow(hz)
    when :pop then plip(hz)
    when :bloom then chime(hz * 2, 1.1, 0.75)
    when :hop then chime(hz, 0.5, 0.65)
    when :giggle then giggle(hz)
    when :whoosh then whoosh
    end
  end

  private

  # A round "bwoop" that slides up into its note.
  def blow(hz)
    phase = 0.0
    sound(0.42, 1.0) do |t|
      phase += hz * (0.78 + 0.22 * [t * 14, 1].min) / RATE
      (Math.sin(2 * Math::PI * phase) + 0.18 * Math.sin(4 * Math::PI * phase)) * swell(t, 0.02, 7)
    end
  end

  # A quick, high "plip".
  def plip(hz)
    phase = 0.0
    sound(0.18, 0.55) do |t|
      phase += hz * 2 * (1.3 - 0.3 * [t * 30, 1].min) / RATE
      Math.sin(2 * Math::PI * phase) * swell(t, 0.004, 28)
    end
  end

  # A music-box note: a clear tone with a little shine on top that fades first.
  def chime(hz, seconds, level)
    sound(seconds, level) do |t|
      ring = Math.sin(2 * Math::PI * hz * t) + 0.3 * Math.sin(4 * Math::PI * hz * t) * Math.exp(-t * 7)
      ring * swell(t, 0.006, 4.5)
    end
  end

  # A giggle: four little notes skipping down, each with a wobble.
  def giggle(hz)
    steps = [2.0, 1.78, 1.5, 1.33]
    sound(0.56, 0.7) do |t|
      step = [(t / 0.14).floor, 3].min
      wobble = 1 + 0.03 * Math.sin(2 * Math::PI * 18 * t)
      soft_triangle = 2 / Math::PI * Math.asin(Math.sin(2 * Math::PI * hz * steps[step] * wobble * t))
      soft_triangle * swell(t - step * 0.14, 0.01, 16)
    end
  end

  # A breath of wind: noise, smoothed until only its low hush is left.
  def whoosh
    noise = Random.new(7)
    low = lower = 0.0
    sound(0.7, 0.55) do |t|
      low += (noise.rand * 2 - 1 - low) * 0.08
      lower += (low - lower) * 0.08
      lower * Math.sin(Math::PI * t / 0.7)**2
    end
  end

  # Grows in over `attack` seconds, then fades away at `fade` per second.
  def swell(t, attack, fade)
    [t / attack, 1].min * Math.exp(-t * fade)
  end

  # `seconds` of sound from the block, one number for each moment, made no
  # louder than LOUDEST times `level`, with the very end faded so it never clicks.
  def sound(seconds, level)
    count = (RATE * seconds).round
    wave = Array.new(count) { |i| yield(i.fdiv(RATE)) * [(count - i) / 220.0, 1].min }
    peak = wave.map(&:abs).max
    gain = peak.zero? ? 0 : LOUDEST * level / peak
    wave.map { |sample| sample * gain }
  end

  # "a4" is 440 Hz, and each semitone up is the twelfth root of two higher.
  def frequency(note)
    semitones = NAMES.index(note[/\D+/]) + 12 * (note[/\d+/].to_i + 1) - 69
    440 * 2**(semitones / 12.0)
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

# Fredoka, the round font the Kids apps share: in the folder beside this one,
# or beside the app itself once it is packaged.
ROUND_FONT_FILE = [
  File.join(__dir__, "fonts", "Fredoka.ttf"),
  File.join(__dir__, "Fredoka.ttf"),
  File.join(__dir__, "_fonts", "Fredoka.ttf"),
  File.join(__dir__, "..", "_fonts", "Fredoka.ttf"),
].find { |path| File.exist?(path) }

Shoes.app(title: "Bubble Garden", width: W, height: H, resizable: false) do
  # ---------------------------------------------------------------- small helpers

  def ease_out(t)
    1 - (1 - t.clamp(0, 1))**3
  end

  def hex(color)
    color.delete("#").scan(/../).map { |pair| pair.to_i(16) }
  end

  def flower_look(note)
    FLOWERS.fetch(note[/\D+/])
  end

  def tint(note)
    hex(flower_look(note)[:petals][1])
  end

  # The note each spot across the window sings: low on the left, high on the right.
  def note_at(x)
    NOTES[(x / W.to_f * NOTES.size).floor.clamp(0, NOTES.size - 1)]
  end

  # Lower notes blow bigger bubbles.
  def size_for(note)
    62 - NOTES.index(note) * 2.6 + rand(-4.0..4.0)
  end

  def sound(name, note = "c5")
    @sounds.play(name, note, @clock)
  end

  # Moves a drawable in one message (move sends its left and its top separately).
  def place(drawable, x, y)
    drawable.style(left: px(x), top: px(y))
  end

  # A slot reads a number between -1 and 1 as a share of its parent, and a
  # negative whole number as a distance back from its far edge (as Shoes 3
  # does), so a slot's position goes as a decimal outside -1..1, or 0 or 1.
  def px(v)
    v = v.to_f.round(1)
    return v if v <= -1 || v > 1

    v < 0.5 ? 0 : 1
  end

  # Shows or hides a drawable, and says nothing when it is already that way.
  def visible(drawable, shown)
    hidden = drawable.hidden ? true : false
    drawable.hidden = !shown if hidden == shown
  end

  # One shape can hold many outlines, and it paints as quickly as one. Drawing a
  # flower's petals as one shape, not twelve, keeps the window quick to redraw
  # however full the garden gets. These add an outline to the shape being drawn.
  def round_outline(cx, cy, w, h = w)
    move_to cx + w / 2.0, cy
    arc_to cx, cy, w, h, 0, 2 * Math::PI
  end

  # A petal: a teardrop from near the middle out to `length`, `width` across, pointing at `angle`.
  def petal_outline(cx, cy, angle, length, width)
    ca, sa = Math.cos(angle), Math.sin(angle)
    at = ->(along, across) { [cx + along * ca - across * sa, cy + along * sa + across * ca] }
    move_to(*at.(length * 0.2, 0))
    curve_to(*at.(length * 0.35, width * 0.9), *at.(length * 0.95, width * 0.75), *at.(length, 0))
    curve_to(*at.(length * 0.95, -width * 0.75), *at.(length * 0.35, -width * 0.9), *at.(length * 0.2, 0))
  end

  # A little smile or a closed eye: a curve from (x1, y) to (x2, y) that dips by `dip`.
  def smile_outline(x1, x2, y, dip)
    move_to x1, y
    curve_to x1 + (x2 - x1) * 0.3, y + dip, x1 + (x2 - x1) * 0.7, y + dip, x2, y
  end

  # ---------------------------------------------------------------- the sky

  # The sky is forty thin stripes, each a shade warmer than the one above. One
  # big gradient looks the same, but takes far longer to redraw.
  def sky
    background "#fff3dc"
    top, low = hex("#8fd3ff"), hex("#fff3dc")
    nostroke
    40.times do |i|
      k = i / 39.0
      rect 0, i * 13, W, 13, fill: rgb(*top.zip(low).map { |a, b| (a + (b - a) * k).round })
    end
    nofill
    @rainbow = RAINBOW.each_with_index.map do |color, i|
      r = 300 - i * 13
      arc 620 - r, 470 - r, r * 2, r * 2, Math::PI, 2 * Math::PI, stroke: rgb(*hex(color), 0), strokewidth: 13, hidden: true
    end
    @rainbow_shown = 0.0
    @rainbow_goal = 0.0
    sun
    @clouds = [[110, 34, 150, 9], [430, 104, 120, 6], [700, 50, 170, 12]].map { |x, y, w, speed| cloud(x, y, w, speed) }
  end

  # A smiling sun whose rays turn slowly. Poke it and it giggles.
  def sun
    nostroke
    [150, 124, 100].each_with_index { |d, i| oval 92, 88, d, center: true, fill: rgb(255, 224, 102, 0.1 + i * 0.05) }
    fill "#ffd43b"
    transform :center
    @rays = shape do
      12.times do |i|
        a = i * Math::PI / 6
        tip = [92 + Math.cos(a) * 70, 88 + Math.sin(a) * 70]
        move_to 92 + Math.cos(a - 0.13) * 50, 88 + Math.sin(a - 0.13) * 50
        curve_to(*tip, *tip, 92 + Math.cos(a + 0.13) * 50, 88 + Math.sin(a + 0.13) * 50)
      end
    end
    transform :corner
    oval 92, 88, 88, center: true, fill: "#fff0a0".."#ffc233"
    fill rgb(255, 130, 110, 0.45)
    shape { round_outline(66, 100, 16, 10); round_outline(118, 100, 16, 10) }
    fill INK
    @sun_eyes = shape { round_outline(78, 82, 9, 12); round_outline(106, 82, 9, 12) }
    stroke INK
    strokewidth 3
    nofill
    cap :curve
    @sun_happy = shape(hidden: true) { smile_outline(72, 84, 84, -8); smile_outline(100, 112, 84, -8) }
    shape { smile_outline(78, 106, 100, 13) }
    nostroke
    @sun_turn = 0.0
    @giggling = 0.0
  end

  # A fluffy cloud with a sleepy face, in a slot of its own so it can drift.
  def cloud(x, y, width, speed)
    asleep = awake = nil
    w = width
    slot = stack(left: x, top: y, width: w, height: w * 0.64) do
      nostroke
      fill rgb(196, 222, 246)
      rect w * 0.1, w * 0.4, w * 0.8, w * 0.2, curve: w * 0.1
      fill white
      shape do
        round_outline(w * 0.28, w * 0.36, w * 0.34)
        round_outline(w * 0.5, w * 0.28, w * 0.44)
        round_outline(w * 0.72, w * 0.36, w * 0.32)
        round_outline(w * 0.21, w * 0.45, w * 0.22)
        round_outline(w * 0.79, w * 0.45, w * 0.22)
        round_outline(w * 0.5, w * 0.45, w * 0.6, w * 0.22)
      end
      fill rgb(255, 150, 170, 0.35)
      shape { round_outline(w * 0.37, w * 0.43, w * 0.07, w * 0.04); round_outline(w * 0.63, w * 0.43, w * 0.07, w * 0.04) }
      fill "#5d6f99"
      awake = shape(hidden: true) { round_outline(w * 0.42, w * 0.355, w * 0.05, w * 0.065); round_outline(w * 0.58, w * 0.355, w * 0.05, w * 0.065) }
      stroke "#8a9cc2"
      strokewidth 2
      nofill
      cap :curve
      asleep = shape { smile_outline(w * 0.395, w * 0.445, w * 0.36, w * 0.02); smile_outline(w * 0.555, w * 0.605, w * 0.36, w * 0.02) }
      shape { smile_outline(w * 0.47, w * 0.53, w * 0.44, w * 0.025) }
    end
    Cloud.new(slot: slot, x: x.to_f, y: y.to_f, speed: speed, width: w, bounce: 0.0, asleep: asleep, awake: awake)
  end

  # ---------------------------------------------------------------- the land

  def land
    nostroke
    fill "#aee3a6"
    shape do
      move_to 0, 470
      curve_to 120, 380, 260, 380, 380, 440
      curve_to 470, 400, 560, 360, 700, 410
      curve_to 800, 380, 900, 390, W, 420
      line_to W, 520
      line_to 0, 520
    end
    [[250, 418, 1.0], [612, 398, 0.8], [840, 410, 1.15]].each { |x, y, k| tree(x, y, k) }
    fill "#7fd072"
    shape do
      move_to 0, 486
      curve_to 160, 452, 320, 470, 480, 478
      curve_to 640, 486, 800, 452, W, 470
      line_to W, H
      line_to 0, H
    end
    fill "#6cc163"
    shape do
      move_to 0, 560
      curve_to 240, 540, 520, 575, W, 548
      line_to W, H
      line_to 0, H
    end
    # tufts of grass along the top of the meadow, and little white clover here and there
    patch = Random.new(12)
    fill "#5fbf5a"
    shape do
      48.times do |i|
        x = i * 20 + patch.rand(-6..6)
        y = 476 + patch.rand(0..14) - (i > 24 ? 6 : 0)
        move_to x - 6, y + 8
        curve_to x - 6, y, x - 8, y - 4, x - 10, y - 6
        curve_to x - 4, y - 3, x - 2, y, x, y - 10
        curve_to x + 2, y, x + 4, y - 3, x + 9, y - 7
        curve_to x + 7, y - 2, x + 6, y, x + 6, y + 8
      end
    end
    fill rgb(255, 255, 255, 0.55)
    shape { 30.times { round_outline(patch.rand(10..W - 10), patch.rand(500..H - 8), patch.rand(3..6)) } }
  end

  # A round tree far away on the hills.
  def tree(x, y, k)
    fill "#9c7a5b"
    rect x - 4 * k, y - 6 * k, 8 * k, 26 * k, curve: 3
    fill "#8fd48a".."#5aa860"
    shape { [[-14, -14, 30], [12, -16, 32], [0, -30, 36]].each { |dx, dy, d| round_outline(x + dx * k, y + dy * k, d * k) } }
  end

  # ---------------------------------------------------------------- bubbles

  # A bubble: a see-through ball with a bright rim, a rainbow sheen along its
  # edge and a shine at the top. It lives in a slot of its own, so it moves as one.
  def blow_bubble(x, y, note, size: size_for(note), vx: rand(-14.0..14.0), vy: -rand(34.0..52.0))
    pop(@bubbles.first) if @bubbles.size >= MOST_BUBBLES
    color = tint(note)
    room = size * 1.2
    body = slot = nil
    @bubble_layer.append do
      slot = stack(left: x - room / 2, top: y - room / 2, width: room, height: room) do
        c = room / 2
        body = oval c, c, size, center: true, stroke: rgb(255, 255, 255, 0.8), strokewidth: 2,
          fill: rgb(*color, 0.14)..rgb(255, 255, 255, 0.3)
        nofill
        strokewidth [size / 15.0, 2].max
        [[255, 110, 199, 0.2, 0.9], [96, 214, 255, 0.9, 1.6], [255, 214, 90, 1.6, 2.2]].each do |r, g, b, from, to|
          stroke rgb(r, g, b, 0.6)
          arc c - size * 0.42, c - size * 0.42, size * 0.84, size * 0.84, from, to
        end
        nostroke
        fill rgb(255, 255, 255, 0.92)
        shape { round_outline(c - size * 0.2, c - size * 0.24, size * 0.24, size * 0.15); round_outline(c - size * 0.3, c - size * 0.08, size * 0.07) }
      end
    end
    @bubbles << Bubble.new(x: x.to_f, y: y.to_f, vx: vx, vy: vy, size: size, note: note, age: 0.0,
      life: rand(3.2..5.5), phase: rand * 6, slot: slot, body: body)
    sound(:blow, note)
  end

  # Bubbles drift up and along with the wind, and wobble as they go.
  def float_bubbles(dt)
    wobble = @frame.even?
    popped = []
    @bubbles.each do |bubble|
      bubble.age += dt
      bubble.vx += (@wind * 40 - bubble.vx) * dt * 0.8
      bubble.x += (bubble.vx + Math.sin(@clock * 1.7 + bubble.phase) * 10) * dt
      bubble.y += bubble.vy * dt
      bubble.x = bubble.x.clamp(bubble.size / 2, W - bubble.size / 2)
      room = bubble.size * 1.2
      place(bubble.slot, bubble.x - room / 2, bubble.y - room / 2)
      if wobble
        squash = Math.sin(@clock * 5 + bubble.phase) * 0.05
        bubble.body.style(width: (bubble.size * (1 + squash)).round, height: (bubble.size * (1 - squash)).round)
      end
      popped << bubble if bubble.age > bubble.life || bubble.y < bubble.size / 2 + 4
    end
    popped.each { |bubble| pop(bubble) }
  end

  # Pop! A ring of droplets flies out, and a seed starts falling to the grass.
  def pop(bubble)
    @bubbles.delete(bubble)
    bubble.slot.remove
    sound(:pop, bubble.note)
    ring = bubble.size / 2
    6.times do |i|
      a = i * Math::PI / 3 + rand * 0.4
      speed = rand(60.0..110.0)
      spark(bubble.x + Math.cos(a) * ring, bubble.y + Math.sin(a) * ring, Math.cos(a) * speed, Math.sin(a) * speed,
        rand(4.5..7.0), i.even? ? [255, 255, 255] : tint(bubble.note), life: 0.45)
    end
    drop_seed(bubble.x, bubble.y, bubble.note)
  end

  # ---------------------------------------------------------------- little bits: droplets, pollen, hearts, confetti

  def spark(x, y, vx, vy, size, color, life: 0.6, gravity: 0)
    return if @bits.size > 140

    art = nil
    @bit_layer.append { art = oval(x, y, size, center: true, fill: rgb(*color, 0.9), stroke: rgb(0, 0, 0, 0)) }
    @bits << Bit.new(art: art, x: x, y: y, vx: vx, vy: vy, age: 0.0, life: life, gravity: gravity, color: color)
  end

  # A little heart that floats up and fades.
  def heart(x, y)
    return if @bits.size > 140

    art = nil
    @bit_layer.append do
      nostroke
      fill "#ff6b9d"
      art = shape(left: x, top: y) do
        move_to 0, 7
        curve_to(-9, 0, -9, -8, -4, -8)
        curve_to(-1, -8, 0, -5, 0, -4)
        curve_to(0, -5, 1, -8, 4, -8)
        curve_to(9, -8, 9, 0, 0, 7)
      end
    end
    @bits << Bit.new(art: art, x: x, y: y, vx: rand(-12.0..12.0), vy: -46, age: 0.0, life: 1.1, gravity: 0, color: [255, 107, 157])
  end

  def fade_bits(dt)
    @bits.reject! do |bit|
      bit.age += dt
      k = bit.age / bit.life
      if k >= 1
        bit.art.remove
        next true
      end
      bit.vy += bit.gravity * dt
      bit.x += bit.vx * dt
      bit.y += bit.vy * dt
      bit.art.style(left: bit.x.round(1), top: bit.y.round(1), fill: rgb(*bit.color, 0.9 * (1 - k * k)))
      false
    end
  end

  # ---------------------------------------------------------------- seeds and flowers

  def drop_seed(x, y, note)
    return if @seeds.size > 30

    art = nil
    color = tint(note)
    @bit_layer.append do
      art = stack(left: x - 9, top: y - 9, width: 18, height: 18) do
        nostroke
        oval 9, 9, 18, center: true, fill: rgb(*color, 0.3)
        oval 9, 9, 8, center: true, fill: rgb(*color)
        oval 7.5, 7.5, 3, center: true, fill: white
      end
    end
    @seeds << Seed.new(x: x.to_f, y: y.to_f, vy: 30.0, age: 0.0, note: note, art: art)
  end

  # Seeds float down, swaying, and plant themselves when they reach the meadow.
  def fall_seeds(dt)
    @seeds.reject! do |seed|
      seed.age += dt
      seed.vy = [seed.vy + 260 * dt, 190].min
      seed.y += seed.vy * dt
      seed.x += Math.sin(seed.age * 4) * 18 * dt
      place(seed.art, seed.x - 9, seed.y - 9)
      landed = seed.y >= 520
      if landed
        seed.art.remove
        plant(seed.x, seed.note)
      end
      landed
    end
  end

  # Every bed has a row of spots a flower can grow in.
  def make_spots
    BEDS.each_index.flat_map do |row|
      (0...14).map { |i| { row: row, x: 36 + i * 66 + row * 22 + rand(-5..5), flower: nil } }
        .select { |spot| spot[:x] < W - 24 }
    end
  end

  # A seed grows in the nearest empty spot. When the garden is full there, the
  # flower already standing nearest gives a happy hop instead.
  def plant(x, note)
    free = @spots.reject { |spot| spot[:flower] }.min_by { |spot| (spot[:x] - x).abs + rand * 30 }
    if free.nil? || (free[:x] - x).abs > 150
      nearest = @flowers.select { |flower| flower.grow >= 1 }.min_by { |flower| (flower.x - x).abs }
      hop(nearest) if nearest
      return
    end
    grow_flower(free, note)
  end

  # A new flower: a stem, two leaves, and a head in a slot of its own, so it
  # can sway and hop as one.
  def grow_flower(spot, note, grown: false)
    bed = BEDS[spot[:row]]
    scale = bed[:scale]
    radius = 27 * scale
    flower = Flower.new(spot: spot, note: note, x: spot[:x].to_f, base: bed[:y] + rand(-3..3),
      height: (70 + rand(0..24)) * scale, radius: radius, box: (radius * 2.8).round, grow: grown ? 1.0 : 0.0,
      phase: rand * 6, hop: 1.0, stir: 0.0, chimed: -9.0, blink: rand(2.0..6.0), shown: nil)
    spot[:flower] = flower
    box = flower.box
    @beds[spot[:row]].append do
      stroke "#3f9b3f"
      strokewidth 5 * scale
      cap :curve
      tip = grown ? flower.base - flower.height : flower.base
      flower.stem = line(flower.x, flower.base, flower.x, tip)
      nostroke
      flower.leaves = leaves(flower.x, flower.base - flower.height * 0.3, 21 * scale, grown)
      flower.head = stack(left: flower.x - box / 2.0, top: tip - box / 2.0, width: box, height: box, hidden: !grown) {}
    end
    draw_head(flower, 1.0, awake: true) if grown
    @flowers << flower
    flower
  end

  # Two leaves on the stem, one each side, as one shape.
  def leaves(x, y, size, shown)
    fill "#86d876".."#3f9b3f"
    shape(hidden: !shown) do
      [[-1, y], [1, y - size * 0.6]].each do |side, ly|
        move_to x, ly
        curve_to x + side * size * 0.3, ly - size * 0.6, x + side * size * 0.9, ly - size * 0.7, x + side * size, ly - size * 0.5
        curve_to x + side * size * 0.7, ly + size * 0.05, x + side * size * 0.3, ly + size * 0.1, x, ly
      end
    end
  end

  # The stem grows, the leaves come out on the way up, the head springs open
  # (drawn again a little bigger every other frame, overshooting and settling
  # back), and then the flower opens its eyes, sings its note and gives a hop.
  def grow_flowers(dt)
    @flowers.each do |flower|
      next if flower.grow >= 1

      before = flower.grow
      flower.grow = [flower.grow + dt / 1.3, 1].min
      g = flower.grow
      flower.stem.style(y2: (flower.base - flower.height * ease_out(g / 0.4)).round(1)) if before < 0.4
      flower.leaves.show if before < 0.2 && g >= 0.2
      if before < 0.4 && g >= 0.4
        flower.head.show
        flower.shown = nil # so the head and the tip of the stem are placed together
      end
      if before < 0.8 && g >= 0.8
        bloomed(flower)
      elsif g >= 0.4 && g < 0.8 && @frame.even?
        draw_head(flower, spring((g - 0.4) / 0.4), awake: false)
      end
    end
  end

  # Overshoots a little and settles back, like something springing open.
  def spring(t)
    t = t.clamp(0, 1)
    1 + 2.7 * (t - 1)**3 + 1.7 * (t - 1)**2
  end

  def bloomed(flower)
    draw_head(flower, 1.0, awake: true)
    flower.hop = 0.0
    sound(:bloom, flower.note)
    top = flower.base - flower.height
    4.times { |i| spark(flower.x, top, Math.cos(i * 1.57 + 0.8) * 70, Math.sin(i * 1.57 + 0.8) * 70, 6, tint(flower.note), life: 0.5) }
    @rainbow_goal = 1.0 if @flowers.count { |f| f.grow >= 0.8 } >= 12
    @party_at ||= @clock + 0.6 if @spots.all? { |spot| spot[:flower] }
  end

  # Draws a flower's head into its slot at `k` times its full size: the petals,
  # a round middle, and a face that is asleep until the flower has opened.
  def draw_head(flower, k, awake:)
    flower.head.clear do
      cx = cy = flower.box / 2.0
      r = flower.radius * k
      look = flower_look(flower.note)
      nostroke
      petals(look, cx, cy, r)
      oval cx, cy, r * (look[:kind] == :daisy ? 0.92 : 1.0), center: true, fill: look[:middle][0]..look[:middle][1] if look[:middle]
      face(flower, cx, look[:kind] == :tulip ? cy + r * 0.12 : cy, r * 0.5, awake)
    end
  end

  # Each kind of flower has its own petals, all of them in one shape.
  def petals(look, cx, cy, r)
    fill look[:petals][0]..look[:petals][1]
    case look[:kind]
    when :blossom
      shape { 5.times { |i| a = -Math::PI / 2 + i * 2 * Math::PI / 5; round_outline(cx + Math.cos(a) * r * 0.62, cy + Math.sin(a) * r * 0.62, r * 1.02) } }
    when :sunny
      shape { 10.times { |i| petal_outline(cx, cy, i * Math::PI / 5, r * 1.18, r * 0.38) } }
    when :tulip
      shape do
        move_to cx - r * 0.8, cy - r * 0.6
        line_to cx - r * 0.4, cy - r * 0.22
        line_to cx, cy - r * 0.8
        line_to cx + r * 0.4, cy - r * 0.22
        line_to cx + r * 0.8, cy - r * 0.6
        curve_to cx + r * 0.95, cy + r * 0.3, cx + r * 0.5, cy + r * 0.85, cx, cy + r * 0.85
        curve_to cx - r * 0.5, cy + r * 0.85, cx - r * 0.95, cy + r * 0.3, cx - r * 0.8, cy - r * 0.6
      end
    when :puff
      shape { 8.times { |i| a = i * Math::PI / 4; round_outline(cx + Math.cos(a) * r * 0.64, cy + Math.sin(a) * r * 0.64, r * 0.72) } }
    when :daisy
      shape { 12.times { |i| petal_outline(cx, cy, i * Math::PI / 6, r * 1.2, r * 0.26) } }
    end
  end

  # Two shiny eyes, rosy cheeks and a smile. The eyes close for a blink, and
  # stay closed while a new flower is still opening.
  def face(flower, cx, cy, r, awake)
    fill rgb(255, 120, 150, 0.5)
    shape { round_outline(cx - r * 0.72, cy + r * 0.3, r * 0.42, r * 0.26); round_outline(cx + r * 0.72, cy + r * 0.3, r * 0.42, r * 0.26) }
    fill INK
    eyes = shape(hidden: !awake) { [-1, 1].each { |side| round_outline(cx + side * r * 0.38, cy - r * 0.08, r * 0.26, r * 0.34) } }
    fill white
    shines = shape(hidden: !awake) { [-1, 1].each { |side| round_outline(cx + side * r * 0.38 - r * 0.05, cy - r * 0.16, r * 0.1) } }
    flower.eyes = [eyes, shines]
    stroke INK
    strokewidth [r * 0.13, 1.2].max
    nofill
    flower.shut = shape(hidden: awake) { [-1, 1].each { |side| x = cx + side * r * 0.38; smile_outline(x - r * 0.15, x + r * 0.15, cy - r * 0.06, r * 0.16) } }
    shape { smile_outline(cx - r * 0.3, cx + r * 0.3, cy + r * 0.26, r * 0.32) }
    nostroke
  end

  def open_eyes(flower, open)
    flower.eyes.each { |eye| visible(eye, open) }
    visible(flower.shut, !open)
  end

  # A flower stands still until something stirs it: the wind, a hop, or the
  # pointer brushing past. Then it sways, and settles again. (Standing still
  # when nothing is happening means the window only redraws what moves.)
  def sway_flowers(dt)
    @flowers.each do |flower|
      next if flower.grow < 0.4

      flower.hop = [flower.hop + dt / 0.5, 1].min
      flower.stir = [flower.stir - dt * 0.7, @wind.abs].max
      lift = Math.sin(flower.hop * Math::PI) * 14
      lean = Math.sin(@clock * 7 + flower.phase) * 5 * flower.stir + @wind * 9
      x = (flower.x + lean).round
      y = (flower.base - flower.height - lift).round
      if [x, y] != flower.shown
        flower.shown = [x, y]
        place(flower.head, x - flower.box / 2.0, y - flower.box / 2.0)
        flower.stem.style(x2: x, y2: y)
      end
      blink(flower, dt) if flower.grow >= 1
    end
  end

  def blink(flower, dt)
    flower.blink -= dt
    return if flower.blink > 0

    closing = flower.shut.hidden ? true : false
    open_eyes(flower, !closing)
    flower.blink = closing ? 0.16 : rand(2.5..7.0)
  end

  def hop(flower)
    return if flower.nil? || flower.grow < 1 || flower.hop < 0.6

    flower.hop = 0.0
    sound(:hop, flower.note)
    heart(flower.x, flower.base - flower.height - flower.radius * 1.3)
  end

  # The pointer brushing through a flower makes it wiggle and chime, like a wind chime.
  def brush(x, y)
    @flowers.each do |flower|
      next unless flower.grow >= 1 && flower.shown
      next unless Math.hypot(flower.shown[0] - x, flower.shown[1] - y) < flower.radius * 1.2

      flower.stir = 1.0
      next if @clock - flower.chimed < 1.2

      flower.chimed = @clock
      sound(:hop, flower.note)
    end
  end

  # When every spot has a flower, they hop one after another, left to right,
  # each singing its note, while confetti drifts down from the sky.
  def garden_party
    return unless @party_at && @clock >= @party_at

    time = @clock - @party_at
    @flowers.each do |flower|
      moment = flower.x / W * 2.4
      hop(flower) if moment < time && moment >= time - 1.0 / FPS
    end
    spark(rand(0..W), -8, rand(-20..20), rand(60..100), 8, hex(RAINBOW.sample), life: 6) if @frame.even?
    @party_at = nil if time > 3.5
  end

  # ---------------------------------------------------------------- butterflies

  def butterfly
    colors = [["#ffe066", "#ff922b"], ["#a5d8ff", "#4c6ef5"], ["#ffc9e3", "#e64980"], ["#d0bfff", "#7048e8"]][@visitors % 4]
    @visitors += 1
    wings = slot = nil
    side = rand < 0.5 ? -40 : W + 40
    @butterfly_layer.append do
      slot = stack(left: side, top: 200, width: 64, height: 56) do
        nostroke
        fill colors[0]..colors[1]
        wings = [[20, 20, 26, 22], [44, 20, 26, 22], [22, 36, 18, 16], [42, 36, 18, 16]].map do |x, y, w, h|
          oval x, y, w, h, center: true
        end
        fill "#5c3d7a"
        shape { round_outline(32, 30, 7, 24); round_outline(32, 16, 11) }
        fill white
        shape { round_outline(29.5, 15, 3.4); round_outline(34.5, 15, 3.4) }
        stroke "#5c3d7a"
        strokewidth 1.6
        nofill
        cap :curve
        shape do
          move_to 30, 11
          curve_to 28, 6, 25, 4, 23, 4
          move_to 34, 11
          curve_to 36, 6, 39, 4, 41, 4
        end
      end
    end
    @butterflies << Butterfly.new(x: side.to_f, y: 200.0, flower: nil, state: :fly, wait: 0.0, phase: rand * 6,
      slot: slot, wings: wings, visits: 0, spin: 0.0)
  end

  # One butterfly for every six flowers (three at most), and one more for the
  # rainbow. They arrive one at a time, a couple of seconds apart.
  def invite_butterflies
    return if @clock < @next_visitor

    wanted = [@flowers.count { |flower| flower.grow >= 1 } / 6, 3].min + (@rainbow_goal > 0 ? 1 : 0)
    return unless @butterflies.count { |b| b.state != :leave } < wanted

    butterfly
    @next_visitor = @clock + 2.5
  end

  # Each butterfly flies to a flower, sits a while, visits a few more, then leaves.
  def flutter(dt)
    @butterflies.reject! do |b|
      b.phase += dt
      case b.state
      when :fly
        b.flower ||= @flowers.select { |flower| flower.grow >= 1 }.sample
        if b.flower.nil? || b.visits >= 3
          b.state = :leave
        elsif steer(b, perch(b.flower), 90, dt) < 4
          b.state = :sit
          b.wait = rand(2.0..4.0)
        end
      when :sit
        b.wait -= dt
        b.x, b.y = perch(b.flower)
        if b.wait <= 0
          b.visits += 1
          b.flower = nil
          b.state = :fly
        end
      when :leave
        steer(b, [b.x < W / 2 ? -80 : W + 80, 120], 110, dt)
      end
      loop_the_loop(b, dt) if b.spin > 0
      flap(b)
      place(b.slot, b.x - 32, b.y - 28)
      gone = b.state == :leave && (b.x < -70 || b.x > W + 70)
      b.slot.remove if gone
      gone
    end
  end

  # Where a butterfly sits on a flower: just above its head.
  def perch(flower)
    [flower.shown[0].to_f, flower.shown[1] - flower.radius * 0.9 - 14]
  end

  # Moves a butterfly towards a point with a gentle bob. Returns how far it still has to go.
  def steer(b, target, speed, dt)
    dx = target[0] - b.x
    dy = target[1] - b.y
    distance = Math.hypot(dx, dy)
    return distance if distance.zero?

    step = [speed * dt, distance].min
    b.x += dx / distance * step
    b.y += dy / distance * step + Math.sin(b.phase * 5) * 30 * dt
    distance
  end

  # A poked butterfly flies a happy little circle.
  def loop_the_loop(b, dt)
    b.spin -= dt
    b.x += Math.cos(b.spin * 8) * 120 * dt
    b.y += Math.sin(b.spin * 8) * 120 * dt
  end

  # Wings open and close: quickly in the air, slowly while sitting on a flower.
  def flap(b)
    beat = b.state == :sit ? 2.2 : 11
    open = 0.3 + 0.7 * Math.cos(b.phase * beat).abs
    [[26, -1], [26, 1], [18, -1], [18, 1]].each_with_index do |(w, side), i|
      width = (w * open).round(1)
      b.wings[i].style(width: width, left: (32 + side * (width / 2 + 2)).round(1))
    end
  end

  # ---------------------------------------------------------------- the grown-up way out

  # Held down, Escape repeats many times a second (a held key repeats every
  # thirtieth to tenth of a second, once the first half second or so has
  # passed). Two seconds of that and the garden closes. A tap, taps a little
  # apart, or a small child mashing other keys too, only show the hint.
  def escape_pressed
    @leave_since = nil if @leave_since && @clock - @leave_last > leave_gap
    @leave_since ||= @clock
    @leave_last = @clock
    @leave_card.show
  end

  # How long Escape can go quiet and still count as held: longer while the
  # key is waiting to start repeating.
  def leave_gap
    @clock - @leave_since < 0.8 ? 0.8 : 0.25
  end

  def not_leaving
    @leave_since = nil
    @leave_card.hide
  end

  def watch_escape
    return unless @leave_since
    return not_leaving if @clock - @leave_last > leave_gap

    held = @leave_last - @leave_since
    @leave_ring.style(angle2: -Math::PI / 2 + 2 * Math::PI * (held / 2.0).clamp(0.02, 1))
    return if held < 2

    @leaving = true
    close
  end

  # ---------------------------------------------------------------- the speaker button

  def speaker_button
    stack(left: W - 88, top: 16, width: 72, height: 72) do
      background rgb(255, 255, 255, 0.6), curve: 24
      nostroke
      fill "#5b4b8a"
      shape do
        move_to 16, 30
        line_to 24, 30
        line_to 38, 17
        line_to 38, 55
        line_to 24, 42
        line_to 16, 42
      end
      stroke "#5b4b8a"
      strokewidth 3.5
      nofill
      cap :curve
      @waves = shape do
        move_to 44, 28
        curve_to 48, 32, 48, 40, 44, 44
        move_to 49, 21
        curve_to 57, 29, 57, 43, 49, 51
      end
      @hush = line(44, 26, 60, 46, hidden: true)
    end
  end

  def toggle_sound
    @sounds.muted = !@sounds.muted
    @waves.hidden = @sounds.muted
    @hush.hidden = !@sounds.muted
  end

  # ---------------------------------------------------------------- what every key, click and wiggle does

  def key_down(key)
    @quiet = 0.0
    name = key.to_s.sub(/\A(control_|shift_|alt_)+/, "")
    return escape_pressed if name == "escape"

    not_leaving if @leave_since
    case name
    when " " then return blow_bubble(W / 2 + rand(-80..80), 540, "c4", size: 112, vy: -30.0)
    when "\n", "enter" then return fanfare
    when "left", "right" then return gust(name == "left" ? -1 : 1)
    when "up" then return lift
    when "down" then return @flowers.each { |flower| hop(flower) if rand < 0.5 }
    end
    # a held key repeats quickly: it blows about seven bubbles a second
    return if @last_key == [name, (@clock * 7).floor]

    @last_key = [name, (@clock * 7).floor]
    row = KEY_ROWS.index { |keys| keys.include?(name.downcase) }
    x = row ? 50 + (KEY_ROWS[row].index(name.downcase) + 0.5) / KEY_ROWS[row].size * (W - 100) : rand(60..W - 60)
    blow_bubble(x, 505 + (row || 2) * 12, note_at(x))
  end

  # Return blows five bubbles in a fan, singing up the scale.
  def fanfare
    %w[c5 d5 e5 g5 a5].each_with_index do |note, i|
      timer(i * 0.12) { blow_bubble(W / 2 + (i - 2) * 70, 560, note, vx: (i - 2) * 16.0) }
    end
  end

  def gust(side)
    @wind = side * 1.0
    whoosh
  end

  # Up sends every bubble higher, faster.
  def lift
    @bubbles.each { |bubble| bubble.vy -= 40 }
    whoosh
  end

  # A scrolling trackpad or a held arrow key sends many gusts; one breath of
  # wind at a time is plenty.
  def whoosh
    return if @clock - @whooshed < 0.8

    @whooshed = @clock
    sound(:whoosh)
  end

  # A press anywhere blows a bubble there, and holding the button keeps blowing.
  # Whatever was under the pointer joins in: the sun giggles, a cloud wakes up
  # and sprinkles, a butterfly loops, a flower hops, a bubble pops.
  def press(x, y)
    @quiet = 0.0
    return toggle_sound if x > W - 92 && y < 92

    @holding = true
    @blown_at = @clock
    if Math.hypot(x - 92, y - 88) < 60
      @giggling = 1.4
      sound(:giggle, "c5")
    end
    cloud = @clouds.find { |c| x.between?(c.x, c.x + c.width) && y.between?(c.y, c.y + c.width * 0.6) }
    sprinkle(cloud) if cloud
    b = @butterflies.find { |fly| Math.hypot(fly.x - x, fly.y - y) < 36 }
    if b
      b.spin = 0.8
      3.times { heart(b.x + rand(-10..10), b.y) }
      sound(:bloom, "e5")
    end
    flower = @flowers.find { |f| f.shown && f.grow >= 1 && Math.hypot(f.shown[0] - x, f.shown[1] - y) < f.radius * 1.3 }
    hop(flower)
    bubble = @bubbles.reverse.find { |bub| Math.hypot(bub.x - x, bub.y - y) < bub.size / 2 }
    return pop(bubble) if bubble
    return if cloud || b || flower

    blow_bubble(x, y, note_at(x), vy: -rand(40.0..60.0))
  end

  # A poked cloud opens its eyes and sprinkles a little shiny rain.
  def sprinkle(cloud)
    cloud.bounce = 1.0
    6.times do |i|
      spark(cloud.x + cloud.width * (0.2 + i * 0.12), cloud.y + cloud.width * 0.5, 0, rand(40.0..90.0), 6,
        [116, 192, 252], life: 1.6, gravity: 160)
    end
    sound(:hop, "g4")
  end

  # While the button is held, the pointer is a bubble wand.
  def blow_while_held
    held, x, y = mouse
    @holding = false if held != 1
    visible(@wand, @holding)
    return unless @holding

    place(@wand, x - 22, y - 22)
    return if @clock - @blown_at < 0.16

    @blown_at = @clock
    blow_bubble(x + rand(-6..6), y + rand(-6..6), note_at(x), vy: -rand(40.0..70.0))
  end

  # A wiggle of the mouse leaves a trail of golden pollen, and flowers it
  # brushes past wiggle and chime.
  def wiggle(x, y)
    last = @pointer
    @pointer = [x, y]
    return if last.nil? || Math.hypot(x - last[0], y - last[1]) < 5

    @quiet = 0.0
    return if @holding

    spark(x + rand(-4..4), y + rand(-4..4), rand(-10..10), rand(-24..-8), rand(3.0..5.0), [255, 212, 59], life: 0.8)
    brush(x, y)
  end

  # Nobody has touched anything for a while: the garden blows a bubble of its own.
  def daydream(dt)
    @quiet += dt
    return if @quiet < 5

    @quiet = 1.5
    source = @flowers.select { |flower| flower.grow >= 1 }.sample
    x = source ? source.x : rand(80..W - 80)
    blow_bubble(x, source ? source.base - source.height : 520, note_at(x), vy: -38.0)
  end

  # ---------------------------------------------------------------- every frame

  def tick(dt)
    @frame += 1
    @clock += dt
    @wind *= 0.97
    @wind = 0.0 if @wind.abs < 0.01
    blow_while_held
    daydream(dt)
    float_bubbles(dt)
    fall_seeds(dt)
    grow_flowers(dt)
    sway_flowers(dt)
    garden_party
    invite_butterflies
    flutter(dt)
    fade_bits(dt)
    shine(dt)
    watch_escape
  end

  # The sun's rays turn, the clouds drift, and the rainbow fades in when it is time.
  def shine(dt)
    @giggling = [@giggling - dt, 0].max
    @sun_turn += dt * (@giggling > 0 ? 90 : 6)
    @rays.style(rotate: @sun_turn.round(1)) if @frame % 3 == 0 || @giggling > 0
    visible(@sun_eyes, @giggling <= 0)
    visible(@sun_happy, @giggling > 0)
    @clouds.each do |c|
      c.x += c.speed * dt
      c.x = -c.width - 10.0 if c.x > W + 10
      c.bounce = [c.bounce - dt * 0.8, 0].max
      at = [c.x.round, (c.y - Math.sin(c.bounce * Math::PI * 3) * 6 * c.bounce).round]
      place(c.slot, *at) unless at == c.shown
      c.shown = at
      visible(c.awake, c.bounce > 0)
      visible(c.asleep, c.bounce <= 0)
    end
    return if @rainbow_shown >= @rainbow_goal

    @rainbow_shown = [@rainbow_shown + dt / 3, @rainbow_goal].min
    RAINBOW.each_with_index do |color, i|
      @rainbow[i].style(stroke: rgb(*hex(color), 0.5 * @rainbow_shown), hidden: false)
    end
  end

  # ---------------------------------------------------------------- building the garden

  @sounds = GardenSounds.new
  @round = (ROUND_FONT_FILE && font(ROUND_FONT_FILE)&.first) || "Arial Rounded MT Bold"
  @frame = 0
  @clock = 0.0
  @wind = 0.0
  @quiet = 0.0
  @visitors = 0
  @next_visitor = 0.0
  @bubbles = []
  @seeds = []
  @bits = []
  @flowers = []
  @butterflies = []
  @holding = false
  @blown_at = 0.0
  @whooshed = -1.0

  sky
  land
  @spots = make_spots
  @beds = BEDS.map { stack(left: 0, top: 0, width: W, height: H) {} }
  @butterfly_layer = stack(left: 0, top: 0, width: W, height: H) {}
  @bubble_layer = stack(left: 0, top: 0, width: W, height: H) {}
  @bit_layer = stack(left: 0, top: 0, width: W, height: H) {}

  # three flowers are already out to say hello
  [[3, "c5"], [18, "e5"], [35, "g4"]].each { |i, note| grow_flower(@spots[i], note, grown: true) }

  # the wand that follows the pointer while the button is held
  @wand = stack(left: 0, top: 0, width: 44, height: 70, hidden: true) do
    stroke "#b47ae8"
    strokewidth 5
    nofill
    oval 22, 22, 32, center: true
    strokewidth 6
    cap :curve
    line 22, 38, 22, 66
  end

  speaker_button
  @leave_card = stack(left: W / 2 - 190, top: 20, width: 380, height: 70, hidden: true) do
    background rgb(61, 43, 31, 0.8), curve: 35
    nofill
    stroke rgb(255, 255, 255, 0.25)
    strokewidth 6
    oval 38, 35, 40, center: true
    stroke "#ffd43b"
    cap :curve
    @leave_ring = arc 18, 15, 40, 40, -Math::PI / 2, -Math::PI / 2 + 0.1
    para "Keep holding Esc to leave", font: @round, size: 17, stroke: white, margin: [76, 22, 0, 0]
  end

  click { |_button, x, y| press(x, y) }
  release { @holding = false }
  motion { |x, y| wiggle(x, y) }
  leave { @pointer = nil }
  keypress { |key| key_down(key) }
  wheel { |delta, _x, _y| gust(delta.positive? ? -1 : 1) }

  animate(FPS) { tick(1.0 / FPS) }
end
