# Peekaboo Moles: friendly moles in party hats pop out of their holes to play.
#
# A mole comes up with its paws over its eyes, then peekaboo! Tap it (or press
# a key: the left of the keyboard is the moles on the left) and it giggles,
# sings its note and sends a star up to the row at the top. Tap a hole with
# nobody in it and its mole pops up to see who knocked. Nothing is ever missed
# and nothing is ever lost; ten stars and the moles throw a party and put on
# new hats.
#
# For children of five and up there is Big kid mode, the stopwatch button: a
# gentle sixty-second round while the sun crosses the sky, with a score, moles
# that get a little quicker as the round goes on, and a trophy at the end. The
# best score is kept in your Application Support folder.
#
# Made for small hands: every key, click and wiggle does something, the moles
# are big, nothing flashes, and nobody is ever told they missed. The speaker in
# the corner turns the sound off; a grown-up can hold Escape for two seconds to
# leave (Cmd-Q works too). The giggles are made right here in Ruby, soft notes
# on a pentatonic scale written once to little WAV files and played with afplay.

require "json"
require "fileutils"
require "tmpdir"

W, H = 960, 640
FPS = 30
ROUND = 60 # seconds in a Big kid round
SAVE_FILE = File.join(Dir.home, "Library", "Application Support", "Peekaboo Moles", "best.json")

# Seven holes: where each is, how big its mole is, and the note it sings.
# Left to right they climb the pentatonic scale, so tapping along the row plays a tune.
HOLES = [
  [125, 522, 1.0, "c4"], [250, 362, 0.85, "d4"], [365, 522, 1.0, "e4"], [480, 362, 0.85, "g4"],
  [600, 522, 1.0, "a4"], [710, 362, 0.85, "c5"], [835, 522, 1.0, "d5"],
]
# Which hole each key knocks on: the top two rows of the keyboard are the back
# holes, the bottom two the front ones, left to right as the keys are.
BACK_KEYS = ["1234567890-=", "qwertyuiop[]"]
FRONT_KEYS = ["asdfghjkl;'", "zxcvbnm,./"]
HATS = %i[party top_hat propeller flower bow beanie chef cowboy]
STAR_NOTES = %w[c5 d5 e5 g5 a5 c6 d6 e6 g6 a6] # the stars climb the scale as the row fills
INK = "#3b2a22"
# A mole's window, in pixels for a full-size mole: it is WINDOW_W wide and
# WINDOW_H tall, the hole's middle is BASE from its top, and the mole's middle
# is MOLE_X across the mole's own slot, which rests SLIDE in from the window's
# edge (room to wiggle, as a slot's position is never negative here).
WINDOW_W, WINDOW_H, BASE, MOLE_X, SLIDE = 200, 246, 220, 94, 6
# The trophy card, and its two buttons: left, top, width, height in the window.
CARD = [W / 2 - 230, 64, 460, 520]
AGAIN = [CARD[0] + 60, CARD[1] + 430, 150, 66]
HOME = [CARD[0] + 250, CARD[1] + 430, 150, 66]
CONFETTI = %w[#ff8787 #ffc078 #ffe066 #8ce99a #74c0fc #b197fc]

Mole = Struct.new(:x, :y, :scale, :note, :hat, :state, :time, :stay, :offset, :window, :slot, :hat_slot,
  :eyes, :shut, :happy, :smile, :grin, :paws, :shown, :hat_shown, :golden, :look, keyword_init: true)
Flyer = Struct.new(:art, :from, :to, :age, :life, :slot, keyword_init: true)
Bit = Struct.new(:art, :x, :y, :vx, :vy, :age, :life, :gravity, :color, keyword_init: true)

# ---------------------------------------------------------------- the sound

# A tiny synthesizer. Each sound is a list of numbers worked out once, written
# to a WAV file, and played by afplay in the background while the game goes on.
class MoleSounds
  RATE = 22_050
  LOUDEST = 0.25 # no sound ever goes above a quarter of full scale
  NAMES = %w[c c# d d# e f f# g g# a a# b]

  attr_reader :last_file, :player, :last_name
  attr_accessor :muted

  def initialize
    @dir = Dir.mktmpdir("peekaboo-moles")
    at_exit { FileUtils.rm_rf(@dir) } # the sounds are only kept while the app runs
    @files = {}
    @started = [] # when recent sounds began, in seconds of game time
  end

  # Plays one sound, unless the sound is off or eight have started in the last second.
  def play(name, note, now)
    return if muted

    @started.reject! { |at| now - at >= 1 }
    return if @started.size >= 8

    @started << now
    @last_name = name
    @last_file = @files[[name, note]] ||= write("#{name}-#{note}", samples(name, note))
    @player = Process.detach(spawn("afplay", @last_file, out: File::NULL, err: File::NULL))
  rescue SystemCallError
    # no afplay here (not a Mac): the moles giggle in silence
  end

  def samples(name, note)
    hz = frequency(note)
    case name
    when :peek then glide(hz, hz * 1.5, 0.22, 0.6)
    when :boo then notes([hz * 1.5, hz * 2], 0.1, 0.8)
    when :giggle then giggle(hz)
    when :ting then chime(hz * 2, 0.9, 0.7)
    when :thup then thup
    when :duck then glide(hz * 1.5, hz * 0.8, 0.2, 0.4)
    when :fanfare then notes([hz, hz * 1.26, hz * 1.5, hz * 2], 0.13, 0.9, ring: 0.9)
    when :blip then notes([hz], 0.18, 0.6)
    when :poof then glide(hz * 2, hz * 3, 0.3, 0.45)
    end
  end

  private

  # A soft tone that slides from one pitch to another.
  def glide(from, to, seconds, level)
    phase = 0.0
    sound(seconds, level) do |t|
      phase += (from + (to - from) * t / seconds) / RATE
      Math.sin(2 * Math::PI * phase) * swell(t, 0.012, 9)
    end
  end

  # Notes one after another, each `step` seconds, each a little bell.
  def notes(pitches, step, level, ring: 0.3)
    sound(step * (pitches.size - 1) + ring + 0.1, level) do |t|
      pitches.each_with_index.sum do |hz, i|
        local = t - i * step
        next 0 if local < 0

        (Math.sin(2 * Math::PI * hz * local) + 0.25 * Math.sin(4 * Math::PI * hz * local)) * swell(local, 0.006, 6)
      end
    end
  end

  # A music-box note.
  def chime(hz, seconds, level)
    sound(seconds, level) do |t|
      (Math.sin(2 * Math::PI * hz * t) + 0.3 * Math.sin(4 * Math::PI * hz * t) * Math.exp(-t * 7)) * swell(t, 0.006, 4.5)
    end
  end

  # A giggle: five little notes skipping down, each with a wobble.
  def giggle(hz)
    steps = [2.0, 1.78, 2.0, 1.5, 1.33]
    sound(0.66, 0.8) do |t|
      step = [(t / 0.12).floor, 4].min
      wobble = 1 + 0.035 * Math.sin(2 * Math::PI * 16 * t)
      soft_triangle = 2 / Math::PI * Math.asin(Math.sin(2 * Math::PI * hz * steps[step] * wobble * t))
      soft_triangle * swell(t - step * 0.12, 0.01, 14)
    end
  end

  # A soft knock on the ground.
  def thup
    noise = Random.new(3)
    low = 0.0
    sound(0.25, 0.55) do |t|
      low += (noise.rand * 2 - 1 - low) * 0.1
      (Math.sin(2 * Math::PI * 110 * t) * 0.8 + low) * swell(t, 0.004, 22)
    end
  end

  def swell(t, attack, fade)
    [t / attack, 1].min * Math.exp(-t * fade)
  end

  # `seconds` of sound from the block, made no louder than LOUDEST times
  # `level`, with the very end faded so it never clicks.
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

Shoes.app(title: "Peekaboo Moles", width: W, height: H, resizable: false) do
  # ---------------------------------------------------------------- small helpers

  def hex(color)
    color.delete("#").scan(/../).map { |pair| pair.to_i(16) }
  end

  def mix(a, b, k)
    hex(a).zip(hex(b)).map { |x, y| (x + (y - x) * k).round }
  end

  def ease_out(t)
    1 - (1 - t.clamp(0, 1))**3
  end

  # Overshoots a little and settles back, like something springing up.
  def spring(t)
    t = t.clamp(0, 1)
    1 + 2.7 * (t - 1)**3 + 1.7 * (t - 1)**2
  end

  def sound(name, note = "c5")
    @sounds.play(name, note, @clock)
  end

  # Moves a drawable, its place kept a whole-pixel decimal (px, below).
  def place(drawable, x, y)
    drawable.move(px(x), px(y))
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

  # Many outlines can share one shape, which paints as quickly as one. These
  # add an outline to the shape being drawn.
  def round_outline(cx, cy, w, h = w)
    move_to cx + w / 2.0, cy
    arc_to cx, cy, w, h, 0, 2 * Math::PI
  end

  # A curve from (x1, y) to (x2, y) that dips by `dip`: a smile, or a closed eye.
  def smile_outline(x1, x2, y, dip)
    move_to x1, y
    curve_to x1 + (x2 - x1) * 0.3, y + dip, x1 + (x2 - x1) * 0.7, y + dip, x2, y
  end

  def star_outline(cx, cy, outer, inner)
    10.times do |i|
      a = -Math::PI / 2 + i * Math::PI / 5
      r = i.even? ? outer : inner
      i.zero? ? move_to(cx + Math.cos(a) * r, cy + Math.sin(a) * r) : line_to(cx + Math.cos(a) * r, cy + Math.sin(a) * r)
    end
    line_to cx, cy - outer
  end

  # ---------------------------------------------------------------- the meadow

  # The sky is forty thin stripes, each a shade warmer than the one above
  # (quicker to redraw than one big gradient).
  def sky
    background "#fff0d6"
    nostroke
    @stripes = Array.new(40) { |i| rect 0, i * 9, W, 9, fill: rgb(*mix("#9fdcff", "#fff0d6", i / 39.0)) }
    @sun = stack(left: 110, top: 96, width: 120, height: 120) do
      nostroke
      oval 60, 60, 116, center: true, fill: rgb(255, 224, 102, 0.22)
      fill "#ffd43b"
      transform :center
      @rays = shape do
        12.times do |i|
          a = i * Math::PI / 6
          tip = [60 + Math.cos(a) * 56, 60 + Math.sin(a) * 56]
          move_to 60 + Math.cos(a - 0.14) * 40, 60 + Math.sin(a - 0.14) * 40
          curve_to(*tip, *tip, 60 + Math.cos(a + 0.14) * 40, 60 + Math.sin(a + 0.14) * 40)
        end
      end
      transform :corner
      oval 60, 60, 70, center: true, fill: "#fff0a0".."#ffc233"
      fill rgb(255, 130, 110, 0.45)
      shape { round_outline(40, 70, 12, 8); round_outline(80, 70, 12, 8) }
      stroke INK
      strokewidth 2.6
      nofill
      cap :curve
      shape { smile_outline(44, 54, 58, -5); smile_outline(66, 76, 58, -5) }
      shape { smile_outline(50, 70, 70, 8) }
    end
    @clouds = [[330, 108, 130, 7], [620, 70, 150, 10], [880, 128, 110, 6]].map { |x, y, w, speed| cloud(x, y, w, speed) }
  end

  def cloud(x, y, w, speed)
    slot = stack(left: x, top: y, width: w, height: w * 0.62) do
      nostroke
      fill rgb(206, 228, 247)
      rect w * 0.1, w * 0.4, w * 0.8, w * 0.2, curve: w * 0.1
      fill white
      shape do
        round_outline(w * 0.28, w * 0.36, w * 0.34)
        round_outline(w * 0.5, w * 0.28, w * 0.44)
        round_outline(w * 0.72, w * 0.36, w * 0.32)
        round_outline(w * 0.5, w * 0.45, w * 0.64, w * 0.22)
      end
    end
    { slot: slot, x: x.to_f, y: y, speed: speed, w: w, shown: nil }
  end

  def land
    nostroke
    fill "#b9e4a8"
    shape do
      move_to 0, 300
      curve_to 140, 236, 300, 238, 420, 282
      curve_to 540, 240, 700, 230, 820, 268
      curve_to 880, 250, 930, 250, W, 262
      line_to W, 360
      line_to 0, 360
    end
    barn(812, 262)
    fill "#8fd47c"
    shape do
      move_to 0, 312
      curve_to 200, 290, 420, 316, 640, 300
      curve_to 800, 290, 900, 300, W, 296
      line_to W, H
      line_to 0, H
    end
    fill "#7fcb6c"
    shape do
      move_to 0, 450
      curve_to 260, 430, 560, 470, W, 440
      line_to W, H
      line_to 0, H
    end
    # little white flowers and tufts scattered in the grass
    patch = Random.new(21)
    fill rgb(255, 255, 255, 0.6)
    shape { 40.times { round_outline(patch.rand(10..W - 10), patch.rand(330..H - 10), patch.rand(3..6)) } }
    fill "#6cbc5c"
    shape do
      36.times do
        x = patch.rand(10..W - 10)
        y = patch.rand(340..H - 6)
        move_to x - 5, y
        curve_to x - 6, y - 6, x - 8, y - 9, x - 9, y - 11
        curve_to x - 4, y - 8, x - 1, y - 6, x, y - 12
        curve_to x + 1, y - 6, x + 4, y - 8, x + 8, y - 10
        curve_to x + 6, y - 7, x + 5, y - 4, x + 5, y
      end
    end
  end

  # A small red barn on the far hill.
  def barn(x, y)
    fill "#e8645a"
    shape { move_to x - 30, y + 36; line_to x - 30, y + 6; line_to x, y - 16; line_to x + 30, y + 6; line_to x + 30, y + 36 }
    fill "#fff6ea"
    shape { move_to x - 34, y + 8; line_to x, y - 20; line_to x + 34, y + 8; line_to x + 30, y + 10; line_to x, y - 14; line_to x - 30, y + 10 }
    rect x - 9, y + 14, 18, 22, fill: "#fff6ea"
    fill "#c94d45"
    rect x - 6, y + 17, 12, 19
  end

  # ---------------------------------------------------------------- the moles

  # A mound of earth with a hole in it. The mole lives in a slot that rises and
  # sinks inside a window (another slot) whose bottom edge is the near lip of
  # the hole, so it vanishes into the ground; the front of the mound is drawn
  # over the bottom of the window.
  def mound(m)
    s = m.scale
    x, y = m.x, m.y
    nostroke
    fill rgb(70, 110, 50, 0.18)
    oval x, y + 34 * s, 240 * s, 46 * s, center: true
    fill "#c08a5c".."#9a6a40"
    shape { round_outline(x, y + 14 * s, 216 * s, 92 * s) }
    fill "#4a2e1d".."#2e1b10"
    oval x, y, 128 * s, 42 * s, center: true
    w, h = WINDOW_W * s, WINDOW_H * s
    m.window = stack(left: x - w / 2, top: y + 26 * s - h, width: w, height: h) do
      m.slot = stack(left: SLIDE * s, top: h, width: w - SLIDE * s, height: h) { draw_mole(m, MOLE_X * s, BASE * s, s) }
    end
    fill "#d19a68".."#b07a4f"
    shape do
      move_to x + 64 * s, y
      arc_to x, y, 128 * s, 42 * s, 0, Math::PI
      curve_to x - 80 * s, y + 6 * s, x - 100 * s, y + 20 * s, x - 104 * s, y + 30 * s
      curve_to x - 60 * s, y + 58 * s, x + 60 * s, y + 58 * s, x + 104 * s, y + 30 * s
      curve_to x + 100 * s, y + 20 * s, x + 80 * s, y + 6 * s, x + 64 * s, y
    end
    fill rgb(255, 255, 255, 0.18)
    shape { move_to x - 50 * s, y + 24 * s; curve_to x - 20 * s, y + 30 * s, x + 20 * s, y + 30 * s, x + 50 * s, y + 24 * s; curve_to x + 20 * s, y + 34 * s, x - 20 * s, y + 34 * s, x - 50 * s, y + 24 * s }
  end

  # Draws a mole around (cx, base), base being the hole's middle, `s` its size.
  def draw_mole(m, cx, base, s)
    nostroke
    fill "#a57e5f".."#7d5b42"
    oval cx, base - 56 * s, 112 * s, 154 * s, center: true
    fill "#e3c4a2"
    oval cx, base - 70 * s, 80 * s, 62 * s, center: true
    fill rgb(255, 125, 140, 0.5)
    shape { round_outline(cx - 34 * s, base - 68 * s, 17 * s, 11 * s); round_outline(cx + 34 * s, base - 68 * s, 17 * s, 11 * s) }
    # eyes, open with a shine, or squeezed shut with a giggle
    fill INK
    eyes = shape { [-1, 1].each { |side| round_outline(cx + side * 19 * s, base - 92 * s, 12 * s, 15 * s) } }
    fill white
    shine = shape { [-1, 1].each { |side| round_outline(cx + side * 19 * s - 2.5 * s, base - 96 * s, 4.6 * s) } }
    m.eyes = [eyes, shine]
    stroke INK
    strokewidth 3 * s
    nofill
    cap :curve
    m.happy = shape(hidden: true) { [-1, 1].each { |side| smile_outline(cx + side * 19 * s - 7 * s, cx + side * 19 * s + 7 * s, base - 90 * s, -7 * s) } }
    m.shut = shape(hidden: true) { [-1, 1].each { |side| smile_outline(cx + side * 19 * s - 7 * s, cx + side * 19 * s + 7 * s, base - 93 * s, 4 * s) } }
    # whiskers
    stroke rgb(90, 64, 48, 0.55)
    strokewidth 1.6 * s
    shape do
      [-1, 1].each do |side|
        [[-7, -3], [0, 0], [7, 4]].each do |dy, end_dy|
          move_to cx + side * 16 * s, base - (73 - dy * 0.3) * s
          line_to cx + side * 46 * s, base - (73 - dy - end_dy) * s
        end
      end
    end
    # a small smile, or a big open giggle
    stroke INK
    strokewidth 2.6 * s
    m.smile = shape { smile_outline(cx - 9 * s, cx + 9 * s, base - 58 * s, 6 * s) }
    nostroke
    fill "#7a2e3b"
    m.grin = shape(hidden: true) do
      move_to cx - 12 * s, base - 60 * s
      curve_to cx - 10 * s, base - 44 * s, cx + 10 * s, base - 44 * s, cx + 12 * s, base - 60 * s
      line_to cx - 12 * s, base - 60 * s
    end
    # the nose, big and pink
    fill "#ffb3c1".."#ff7f98"
    oval cx, base - 76 * s, 30 * s, 21 * s, center: true
    fill rgb(255, 255, 255, 0.7)
    oval cx - 6 * s, base - 80 * s, 9 * s, 5 * s, center: true
    # paws, which cover the eyes for peekaboo
    fill "#ffd0cc"
    m.paws = [-1, 1].map do |side|
      shape(left: cx + side * 34 * s, top: base - 12 * s) do
        round_outline(0, 0, 30 * s, 20 * s)
        [-8, 0, 8].each { |dx| round_outline(dx * s, -8 * s, 8 * s) }
      end
    end
    m.hat_slot = stack(left: cx - 60 * s, top: 16 * s, width: 120 * s, height: 90 * s) { hat(m, m.hat, 60 * s, 76 * s, s) }
    m.look = 0
  end

  # Where each paw sits: resting on the lip, over the eyes, or waving hello.
  def paw_spots(m, pose)
    s = m.scale
    cx = MOLE_X * s
    base = BASE * s
    case pose
    when :hide then [[cx - 19 * s, base - 90 * s], [cx + 19 * s, base - 90 * s]]
    when :wave then [[cx - 34 * s, base - 12 * s], [cx + 50 * s, base - 70 * s + Math.sin(@clock * 16) * 8 * s]]
    else [[cx - 34 * s, base - 12 * s], [cx + 34 * s, base - 12 * s]]
    end
  end

  def pose(m, pose)
    paw_spots(m, pose).each_with_index { |(x, y), i| place(m.paws[i], x, y) }
  end

  def face(m, mood)
    m.eyes.each { |eye| visible(eye, mood == :open) }
    visible(m.shut, mood == :blink)
    visible(m.happy, mood == :giggle)
    visible(m.smile, mood != :giggle)
    visible(m.grin, mood == :giggle)
  end

  # ---------------------------------------------------------------- hats

  # Each mole wears a hat, drawn around (cx, bottom): its brim sits on the head.
  def hat(m, kind, cx, bottom, s)
    @propellers.delete(m)
    nostroke
    case kind
    when :party
      fill "#ff8fc7".."#b86bff"
      shape { move_to cx - 26 * s, bottom; line_to cx, bottom - 62 * s; line_to cx + 26 * s, bottom }
      fill "#fff3a3"
      shape { [[-8, -14], [8, -26], [-3, -40], [4, -8]].each { |dx, dy| round_outline(cx + dx * s, bottom + dy * s, 7 * s) } }
      fill "#ffd43b"
      oval cx, bottom - 62 * s, 16 * s, center: true
    when :top_hat
      fill "#4a4458".."#2b2735"
      rect cx - 21 * s, bottom - 50 * s, 42 * s, 46 * s, curve: 4 * s
      rect cx - 34 * s, bottom - 8 * s, 68 * s, 10 * s, curve: 5 * s
      fill "#ff6b6b"
      rect cx - 21 * s, bottom - 18 * s, 42 * s, 8 * s
    when :propeller
      fill "#ffd43b"
      shape { move_to cx - 30 * s, bottom; curve_to cx - 30 * s, bottom - 36 * s, cx + 30 * s, bottom - 36 * s, cx + 30 * s, bottom }
      fill "#4dabf7"
      shape { move_to cx - 10 * s, bottom - 26 * s; curve_to cx - 6 * s, bottom - 12 * s, cx - 6 * s, bottom - 6 * s, cx - 10 * s, bottom; line_to cx + 10 * s, bottom; curve_to cx + 6 * s, bottom - 6 * s, cx + 6 * s, bottom - 12 * s, cx + 10 * s, bottom - 26 * s; curve_to cx + 4 * s, bottom - 28 * s, cx - 4 * s, bottom - 28 * s, cx - 10 * s, bottom - 26 * s }
      rect cx - 2 * s, bottom - 38 * s, 4 * s, 12 * s, fill: "#868e96"
      fill "#ff6b6b"
      transform :center
      @propellers[m] = shape { round_outline(cx - 14 * s, bottom - 40 * s, 26 * s, 7 * s); round_outline(cx + 14 * s, bottom - 40 * s, 26 * s, 7 * s) }
      transform :corner
    when :flower
      fill "#ff8fb1".."#ff5c8a"
      shape { 6.times { |i| a = i * Math::PI / 3; round_outline(cx + 16 * s + Math.cos(a) * 12 * s, bottom - 14 * s + Math.sin(a) * 12 * s, 15 * s) } }
      fill "#ffe066"
      oval cx + 16 * s, bottom - 14 * s, 13 * s, center: true
      fill "#69db7c"
      shape { move_to cx + 2 * s, bottom - 4 * s; curve_to cx - 12 * s, bottom - 12 * s, cx - 20 * s, bottom - 4 * s, cx - 24 * s, bottom + 2 * s; curve_to cx - 12 * s, bottom + 4 * s, cx - 4 * s, bottom + 2 * s, cx + 2 * s, bottom - 4 * s }
    when :bow
      fill "#ff6b9d".."#e64980"
      shape do
        move_to cx, bottom - 12 * s
        curve_to cx - 14 * s, bottom - 34 * s, cx - 38 * s, bottom - 30 * s, cx - 34 * s, bottom - 10 * s
        curve_to cx - 32 * s, bottom + 4 * s, cx - 14 * s, bottom, cx, bottom - 12 * s
        curve_to cx + 14 * s, bottom - 34 * s, cx + 38 * s, bottom - 30 * s, cx + 34 * s, bottom - 10 * s
        curve_to cx + 32 * s, bottom + 4 * s, cx + 14 * s, bottom, cx, bottom - 12 * s
      end
      fill "#fff0f6"
      shape { [[-22, -18], [-16, -6], [22, -18], [16, -6]].each { |dx, dy| round_outline(cx + dx * s, bottom + dy * s, 5 * s) } }
      fill "#c2255c"
      oval cx, bottom - 12 * s, 14 * s, center: true
    when :beanie
      fill "#38d9a9".."#0ca678"
      shape { move_to cx - 30 * s, bottom - 6 * s; curve_to cx - 30 * s, bottom - 48 * s, cx + 30 * s, bottom - 48 * s, cx + 30 * s, bottom - 6 * s }
      fill "#e6fcf5"
      rect cx - 32 * s, bottom - 12 * s, 64 * s, 13 * s, curve: 6 * s
      oval cx, bottom - 44 * s, 18 * s, center: true
    when :chef
      fill "#ffffff"
      shape { [[-16, -30, 26], [0, -40, 30], [16, -30, 26]].each { |dx, dy, d| round_outline(cx + dx * s, bottom + dy * s, d * s) } }
      rect cx - 22 * s, bottom - 28 * s, 44 * s, 26 * s
      fill "#e9ecef"
      rect cx - 23 * s, bottom - 9 * s, 46 * s, 9 * s, curve: 3 * s
    when :cowboy
      fill "#c0864f".."#8f5a2e"
      shape { move_to cx - 20 * s, bottom - 6 * s; curve_to cx - 22 * s, bottom - 40 * s, cx - 6 * s, bottom - 44 * s, cx, bottom - 34 * s; curve_to cx + 6 * s, bottom - 44 * s, cx + 22 * s, bottom - 40 * s, cx + 20 * s, bottom - 6 * s }
      shape { move_to cx - 44 * s, bottom - 16 * s; curve_to cx - 30 * s, bottom + 2 * s, cx + 30 * s, bottom + 2 * s, cx + 44 * s, bottom - 16 * s; curve_to cx + 34 * s, bottom - 4 * s, cx - 34 * s, bottom - 4 * s, cx - 44 * s, bottom - 16 * s }
      fill "#5c3a1e"
      rect cx - 20 * s, bottom - 14 * s, 40 * s, 6 * s
    when :crown
      fill "#ffe066".."#f59f00"
      shape do
        move_to cx - 28 * s, bottom
        line_to cx - 30 * s, bottom - 34 * s
        line_to cx - 15 * s, bottom - 20 * s
        line_to cx, bottom - 42 * s
        line_to cx + 15 * s, bottom - 20 * s
        line_to cx + 30 * s, bottom - 34 * s
        line_to cx + 28 * s, bottom
      end
      fill "#ff6b6b"
      oval cx, bottom - 10 * s, 9 * s, center: true
      fill "#4dabf7"
      shape { round_outline(cx - 17 * s, bottom - 9 * s, 7 * s); round_outline(cx + 17 * s, bottom - 9 * s, 7 * s) }
    end
  end

  # Swaps a mole's hat, with a poof.
  def change_hat(m, kind)
    m.hat = kind
    s = m.scale
    m.hat_slot.clear { hat(m, kind, 60 * s, 76 * s, s) }
  end

  # ---------------------------------------------------------------- how a mole behaves

  # A mole's day: down in its hole, rising with its paws over its eyes, then
  # peekaboo, looking about, and back down. Or just peeking over the edge.
  def pop_up(m, stay: nil)
    return unless m.state == :down || m.state == :peek

    m.state = :rise
    m.time = 0.0
    m.stay = stay || (@big_kid ? big_kid_stay : rand(3.0..4.5))
    pose(m, :hide)
    face(m, :open)
    sound(:peek, m.note)
  end

  def peek(m)
    return unless m.state == :down

    m.state = :peek
    m.time = 0.0
    pose(m, :rest)
    face(m, :open)
  end

  # A tap: the mole giggles, sings its note and sends up a star.
  def tickle(m)
    return if %i[giggle wave sink].include?(m.state)
    return party_giggle(m) if m.state == :dance

    m.state = :giggle
    m.time = 0.0
    face(m, :giggle)
    pose(m, :rest)
    sound(:giggle, m.note)
    2.times { |i| heart(m.x + (i * 2 - 1) * 26 * m.scale, m.y - 120 * m.scale) }
    points = m.golden ? 3 : 1
    if @big_kid
      score(m, points)
    else
      fly_star(m)
    end
  end

  # At the party, a tap gets a giggle and a heart, and the dancing goes on.
  def party_giggle(m)
    sound(:giggle, m.note)
    heart(m.x, m.y - 150 * m.scale)
  end

  # Every frame, each mole moves along its day.
  def live(m, dt)
    m.time += dt
    s = m.scale
    down = WINDOW_H * s
    case m.state
    when :rise
      m.offset = down * (1 - spring(m.time / 0.4))
      boo(m) if m.time >= 0.9
    when :up
      m.offset = 0
      look_about(m)
      m.stay -= dt
      duck(m) if m.stay <= 0
    when :giggle
      m.offset = 0
      if m.time >= 0.9
        m.state = :wave
        m.time = 0.0
        face(m, :open)
      end
    when :wave
      pose(m, :wave)
      duck(m) if m.time >= 0.5
    when :sink
      m.offset = down * ease_out(m.time / 0.3)
      rest(m) if m.time >= 0.3
    when :peek
      m.offset = down - 170 * s * Math.sin(Math::PI * [m.time / 1.6, 1].min)
      rest(m) if m.time >= 1.6
    when :dance
      if m.time.between?(0, 0.4) # springing up out of the hole to join in
        m.offset = [m.offset, down * (1 - spring(m.time / 0.4))].min
      elsif m.time > 0.4 # and bouncing to the music
        m.offset = (Math.sin(m.time * 9) * 0.5 + 0.5) * 22 * s
      end
      if m.time >= 3.0
        m.state = :up
        m.stay = 0.6
        face(m, :open)
        pose(m, :rest)
      end
    end
    wiggle = m.state == :giggle ? Math.sin(m.time * 40) * 5 * s : 0
    at = [(SLIDE * s + wiggle).round(1), m.offset.round(1)]
    place(m.slot, *at) unless at == m.shown
    m.shown = at
    hop = (m.state == :giggle || m.state == :dance ? Math.sin(m.time * 12).abs * 12 * s : 0).round(1)
    place(m.hat_slot, (MOLE_X - 60) * s, 16 * s - hop) unless hop == m.hat_shown
    m.hat_shown = hop
    spin_propeller(m)
    shimmer(m) if m.golden && m.state != :down && @frame % 6 == 0
  end

  # The golden mole twinkles, so it is easy to spot.
  def shimmer(m)
    a = rand * 2 * Math::PI
    spark(m.x + Math.cos(a) * 50 * m.scale, m.y - 110 * m.scale + Math.sin(a) * 60 * m.scale, 0, -20, 7, [255, 212, 59], life: 0.6)
  end

  def boo(m)
    m.state = :up
    m.time = 0.0
    pose(m, :rest)
    sound(:boo, m.note)
  end

  def duck(m)
    m.state = :sink
    m.time = 0.0
    pose(m, :rest)
    sound(:duck, m.note) unless @big_kid
  end

  def rest(m)
    m.state = :down
    m.offset = WINDOW_H * m.scale
    unglow(m) if m.golden
  end

  # A mole that is up blinks now and then.
  def look_about(m)
    blink = (m.time % 3.1) > 2.95
    m.eyes.each { |eye| visible(eye, !blink) }
    visible(m.shut, blink)
  end

  def spin_propeller(m)
    blades = @propellers[m]
    return unless blades

    fast = m.state == :giggle || m.state == :dance
    return unless fast || @frame % 6 == 0

    @spin[m] = (@spin[m] || 0) + (fast ? 40 : 6)
    blades.style(rotate: @spin[m] % 360)
  end

  # ---------------------------------------------------------------- stars and parties (the little ones' game)

  def star_row
    @star_spots = Array.new(10) do |i|
      x = W / 2 - 207 + i * 46
      nostroke
      back = star(x, 48, 5, 20, 9.5, fill: rgb(255, 255, 255, 0.35), stroke: rgb(255, 255, 255, 0.9), strokewidth: 2)
      gold = star(x, 48, 5, 21, 10, fill: "#ffe066".."#fab005", stroke: "#e8a200", strokewidth: 1.5, hidden: true)
      { x: x, back: back, gold: gold }
    end
  end

  # A star flies from the mole up to the next space in the row.
  def fly_star(m)
    return if @stars + @flying.size >= 10

    slot = @star_spots[@stars + @flying.size]
    art = nil
    @top_layer.append do
      nostroke
      fill "#ffe066".."#fab005"
      art = shape(left: m.x, top: m.y - 110 * m.scale) { star_outline(0, 0, 20, 9.5) }
    end
    @flying << Flyer.new(art: art, from: [m.x, m.y - 110 * m.scale], to: [slot[:x], 48], age: 0.0, life: 0.8, slot: slot)
  end

  def fly(dt)
    @flying.reject! do |f|
      f.age += dt
      k = ease_out(f.age / f.life)
      x = f.from[0] + (f.to[0] - f.from[0]) * k
      y = f.from[1] + (f.to[1] - f.from[1]) * k - Math.sin(Math::PI * k) * 90
      place(f.art, x, y)
      next false if f.age < f.life

      f.art.remove
      f.slot[:gold].show
      sound(:ting, STAR_NOTES[@stars])
      @stars += 1
      4.times { |i| spark(x, y, Math.cos(i * 1.57 + 0.4) * 60, Math.sin(i * 1.57 + 0.4) * 60, 6, [255, 212, 59], life: 0.5) }
      party if @stars == 10
      true
    end
  end

  # Ten stars: every mole comes up to dance, confetti falls, and halfway
  # through, poof, everyone is in a new hat.
  def party
    @party = 0.0
    @new_hats = false
    sound(:fanfare, "c5")
    @moles.each_with_index do |m, i|
      m.state = :dance
      m.time = -i * 0.07
      pose(m, :wave)
      face(m, :giggle)
    end
  end

  def keep_partying(dt)
    return unless @party

    @party += dt
    spark(rand(0..W), -8, rand(-20..20), rand(70..110), 8, hex(CONFETTI.sample), life: 5) if @frame.even?
    if @party >= 1.6 && !@new_hats
      @new_hats = true
      @hat_turn += 1
      @moles.each_with_index do |m, i|
        change_hat(m, HATS[(i + @hat_turn) % HATS.size])
        3.times { |j| spark(m.x + (j - 1) * 20, m.y - 160 * m.scale, (j - 1) * 30, -40, 9, [255, 255, 255], life: 0.6) }
      end
      sound(:poof, "c5")
      reset_stars
    end
    @party = nil if @party >= 4.0
  end

  def reset_stars
    @star_spots.each { |slot| slot[:gold].hide }
    @stars = 0
  end

  # ---------------------------------------------------------------- little bits: hearts, sparkles, confetti, dirt

  def spark(x, y, vx, vy, size, color, life: 0.6, gravity: 0)
    return if @bits.size > 120

    art = nil
    @top_layer.append { art = oval(x, y, size, center: true, fill: rgb(*color, 0.9), stroke: rgb(0, 0, 0, 0)) }
    @bits << Bit.new(art: art, x: x, y: y, vx: vx, vy: vy, age: 0.0, life: life, gravity: gravity, color: color)
  end

  def heart(x, y)
    return if @bits.size > 120

    art = nil
    @top_layer.append do
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
    @bits << Bit.new(art: art, x: x, y: y, vx: rand(-14.0..14.0), vy: -55, age: 0.0, life: 1.0, gravity: 0, color: [255, 107, 157])
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

  # A tap on an empty hole kicks up a little dirt.
  def dirt(m)
    5.times { |i| spark(m.x + (i - 2) * 14 * m.scale, m.y + 4, (i - 2) * 30, -rand(60.0..110.0), rand(5.0..8.0), [150, 100, 60], life: 0.6, gravity: 320) }
    sound(:thup)
  end

  # ---------------------------------------------------------------- Big kid mode

  def big_kid_stay
    k = @round_time / ROUND.to_f
    1.9 - 0.95 * k
  end

  def start_countdown
    return if @big_kid || @countdown

    @party = nil
    reset_stars if @stars >= 10
    @countdown = 0.0
    @card.hide
    @moles.each { |m| duck(m) unless m.state == :down }
    @stars_box.hide
    @count_box.show
    @count_text.replace "3"
    sound(:blip, "c5")
  end

  def count_down(dt)
    return unless @countdown

    before = @countdown
    @countdown += dt
    [[0.8, "2", "c5"], [1.6, "1", "c5"], [2.4, "Go!", "g5"]].each do |at, text, note|
      next unless before < at && @countdown >= at

      @count_text.replace text
      sound(:blip, note)
    end
    return if @countdown < 3.0

    @countdown = nil
    @count_box.hide
    @big_kid = true
    @round_time = 0.0
    @points = 0
    @next_pop = 0.3
    @next_gold = rand(8.0..12.0)
    @score_text.replace "0"
    @score_box.show
    @sun_path.each(&:show)
  end

  # The round: the sun crosses the sky, and the moles come up a little more
  # often, and stay up a little less, as it goes.
  def play_round(dt)
    @round_time += dt
    k = [@round_time / ROUND, 1].min
    x, y = sun_at(k)
    place(@sun, x - 60, y - 60)
    sunset(k) if @frame % 10 == 0
    return finish_round if @round_time >= ROUND

    @next_pop -= dt
    return if @next_pop > 0

    @next_pop = 1.15 - 0.6 * k + rand(0.0..0.2)
    busy = @moles.count { |m| m.state != :down }
    return if busy >= 1 + (k > 0.3 ? 1 : 0) + (k > 0.7 ? 1 : 0)

    m = @moles.select { |mole| mole.state == :down }.sample
    return unless m

    if @round_time >= @next_gold
      glow(m)
      @next_gold = @round_time + rand(9.0..13.0)
    end
    pop_up(m)
  end

  # The golden mole wears a crown and is worth three.
  def glow(m)
    m.golden = true
    change_hat(m, :crown)
  end

  def unglow(m)
    m.golden = false
    change_hat(m, HATS[(@moles.index(m) + @hat_turn) % HATS.size])
  end

  def score(m, points)
    @points += points
    @score_text.replace @points.to_s
    label = nil
    @top_layer.append do
      label = para "+#{points}", font: @round_font, size: 26, weight: "bold", stroke: "#ffffff", left: m.x - 20, top: m.y - 170 * m.scale
    end
    @labels << { art: label, y: m.y - 170 * m.scale, x: m.x - 20, age: 0.0 }
    sound(:ting, STAR_NOTES[[@points / 3, 9].min])
  end

  def float_labels(dt)
    @labels.reject! do |label|
      label[:age] += dt
      place(label[:art], label[:x], label[:y] - label[:age] * 50)
      next false if label[:age] < 0.8

      label[:art].remove
      true
    end
  end

  # Where the sun is, `k` of the way through a round: up over the top of the
  # sky, then down behind the hills on the right.
  def sun_at(k)
    [170 + k * 660, 156 - 70 * Math.sin(Math::PI * k) + 150 * k**4]
  end

  # The sky stays blue for most of a round, then turns to evening at the end
  # (a few times a second is plenty).
  def sunset(k)
    evening = ((k - 0.55) / 0.45).clamp(0, 1)
    @stripes.each_with_index do |stripe, i|
      day = mix("#9fdcff", "#fff0d6", i / 39.0)
      eve = mix("#a9b4f2", "#ffc79c", i / 39.0)
      stripe.style(fill: rgb(*day.zip(eve).map { |a, b| (a + (b - a) * evening * 0.8).round }))
    end
  end

  def finish_round
    @big_kid = false
    @moles.each { |m| duck(m) unless m.state == :down }
    @moles.each { |m| unglow(m) if m.golden }
    @score_box.hide
    @sun_path.each(&:hide)
    best_before = @best
    @best = [@best, @points].max
    save_best
    trophy(@points, @points > best_before && best_before > 0)
  end

  # Every round ends with a trophy: gold, silver or bronze, with stars to match.
  def trophy(points, new_best)
    tier = points >= 30 ? 0 : points >= 18 ? 1 : 2
    colors = [["#ffe066", "#f59f00"], ["#f1f3f5", "#adb5bd"], ["#ffc9a3", "#c9773c"]][tier]
    @cup.each { |part| part.style(fill: colors[0]..colors[1]) }
    @handles.each { |handle| handle.style(stroke: colors[1]) }
    @medal_text.replace %w[Gold! Silver! Bronze!][tier]
    @trophy_stars.each_with_index { |s, i| s.hidden = i >= 3 - tier }
    @final_text.replace points.to_s
    @best_text.replace(new_best ? "A new best!" : "Best: #{@best}")
    @card.show
    @card_time = 0.0
    sound(:fanfare, "g4")
    40.times { spark(rand(0..W), -rand(0..200), rand(-20..20), rand(80..130), 8, hex(CONFETTI.sample), life: 5) }
  end

  def back_to_peekaboo
    @card.hide
    @card_time = nil
    @stars_box.show
    place(@sun, 110, 96)
    sunset(0)
  end

  def load_best
    saved = JSON.parse(File.read(SAVE_FILE)) if File.exist?(SAVE_FILE)
    saved.is_a?(Hash) ? saved["best"].to_i : 0
  rescue JSON::ParserError, SystemCallError
    0
  end

  def save_best
    FileUtils.mkdir_p(File.dirname(SAVE_FILE))
    File.write(SAVE_FILE, JSON.generate("best" => @best))
  rescue SystemCallError
    # somewhere read-only: the best score is only forgotten
  end

  # ---------------------------------------------------------------- the grown-up way out

  # Held down, Escape repeats many times a second (a held key repeats every
  # thirtieth to tenth of a second, once the first half second or so has
  # passed). Two seconds of that and the game closes. A tap, taps a little
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

  # ---------------------------------------------------------------- buttons

  # A big round-cornered button for grown-ups and big kids, with an icon.
  def corner_button(left)
    stack(left: left, top: 16, width: 72, height: 72) do
      background rgb(255, 255, 255, 0.6), curve: 24
      yield
    end
  end

  def buttons
    corner_button(16) do
      # a stopwatch with a star on it: Big kid mode
      nostroke
      fill "#5b4b8a"
      rect 31, 11, 10, 8, curve: 2
      oval 36, 40, 44, center: true
      fill "#fff9db"
      oval 36, 40, 34, center: true
      fill "#f59f00"
      shape { star_outline(36, 41, 12, 5.5) }
    end
    corner_button(W - 88) do
      nostroke
      fill "#5b4b8a"
      shape { move_to 16, 30; line_to 24, 30; line_to 38, 17; line_to 38, 55; line_to 24, 42; line_to 16, 42 }
      stroke "#5b4b8a"
      strokewidth 3.5
      nofill
      cap :curve
      @waves = shape { move_to 44, 28; curve_to 48, 32, 48, 40, 44, 44; move_to 49, 21; curve_to 57, 29, 57, 43, 49, 51 }
      @hush = line(44, 26, 60, 46, hidden: true)
    end
  end

  def toggle_sound
    @sounds.muted = !@sounds.muted
    @waves.hidden = @sounds.muted
    @hush.hidden = !@sounds.muted
  end

  # ---------------------------------------------------------------- what every key, click and wiggle does

  def hole_at(x, y)
    @moles.sort_by { |m| -m.y }.find { |m| ((x - m.x) / (100.0 * m.scale))**2 + ((y - (m.y - 60 * m.scale)) / (118.0 * m.scale))**2 <= 1 }
  end

  def press(x, y)
    return toggle_sound if x > W - 92 && y < 92
    return start_countdown if x < 92 && y < 92 && !@big_kid
    return card_press(x, y) if @card_time

    m = hole_at(x, y)
    if m
      knock(m)
    else
      5.times { |i| spark(x, y, Math.cos(i * 1.26) * 70, Math.sin(i * 1.26) * 70, 6, [255, 236, 153], life: 0.45) }
    end
  end

  # A knock on a hole: its mole giggles if it is up, and pops up if it is not
  # (the little ones' game never says "missed").
  def knock(m)
    return dirt(m) if @countdown # 3, 2, 1: the moles are getting ready

    if m.state == :down || m.state == :peek
      dirt(m) if m.state == :down
      pop_up(m, stay: 2.2) unless @big_kid
    else
      tickle(m)
    end
  end

  def inside?(box, x, y)
    left, top, width, height = box
    x.between?(left, left + width) && y.between?(top, top + height)
  end

  def card_press(x, y)
    if inside?(AGAIN, x, y)
      back_to_peekaboo
      start_countdown
    elsif inside?(HOME, x, y)
      back_to_peekaboo
    else
      6.times { |i| spark(x, y, Math.cos(i * 1.05) * 80, Math.sin(i * 1.05) * 80, 7, [255, 212, 59], life: 0.5) }
    end
  end

  def key_down(key)
    name = key.to_s.sub(/\A(control_|shift_|alt_)+/, "").downcase
    return escape_pressed if name == "escape"

    not_leaving if @leave_since
    return card_key(name) if @card_time

    case name
    when " ", "\n", "enter" then return chorus
    when "left" then return look_all(-1)
    when "right" then return look_all(1)
    end
    m = mole_for_key(name) || @moles.sample
    knock(m)
  end

  def mole_for_key(name)
    back = BACK_KEYS.find { |keys| keys.include?(name) }
    front = FRONT_KEYS.find { |keys| keys.include?(name) }
    if back
      [@moles[1], @moles[3], @moles[5]][(back.index(name) * 3 / back.size.to_f).floor]
    elsif front
      [@moles[0], @moles[2], @moles[4], @moles[6]][(front.index(name) * 4 / front.size.to_f).floor]
    end
  end

  def card_key(name)
    back_to_peekaboo if name == "\n" || name == " "
  end

  # Space: every mole plays peekaboo at once (in the little ones' game).
  def chorus
    return if @big_kid || @countdown || @party

    @moles.each_with_index { |m, i| timer(i * 0.06) { pop_up(m, stay: 2.0) } }
  end

  def look_all(side)
    @moles.each do |m|
      next if m.state == :down || m.look == side

      m.look = side
      m.eyes.each { |eye| eye.style(left: side * 4 * m.scale) }
    end
  end

  def wiggle(x, y)
    last = @pointer
    @pointer = [x, y]
    return if last.nil? || Math.hypot(x - last[0], y - last[1]) < 6

    spark(x + rand(-4..4), y + rand(-4..4), rand(-10..10), rand(-24..-8), rand(3.0..5.0), [255, 236, 153], life: 0.7)
    # a mole that is up turns to look at the pointer
    @moles.each do |m|
      next unless m.state == :up

      side = x < m.x - 40 ? -1 : x > m.x + 40 ? 1 : 0
      next if m.look == side

      m.look = side
      m.eyes.each { |eye| eye.style(left: side * 4 * m.scale) }
    end
  end

  # ---------------------------------------------------------------- the little ones' game: moles come and go by themselves

  def little_game(dt)
    @next_pop -= dt
    return if @next_pop > 0 || @party

    @next_pop = rand(1.2..2.2)
    resting = @moles.select { |m| m.state == :down }
    return if @moles.size - resting.size >= 2 || resting.empty?

    m = resting.reject { |mole| mole.equal?(@last_up) }.sample || resting.sample
    @last_up = m
    rand < 0.25 ? peek(m) : pop_up(m)
  end

  # ---------------------------------------------------------------- every frame

  def tick(dt)
    @frame += 1
    @clock += dt
    if @big_kid
      play_round(dt)
    elsif !@countdown && !@card_time
      little_game(dt)
    end
    count_down(dt)
    @moles.each { |m| live(m, dt) }
    fly(dt)
    keep_partying(dt)
    fade_bits(dt)
    float_labels(dt)
    drift(dt)
    watch_escape
    return unless @card_time

    @card_time += dt
    back_to_peekaboo if @card_time > 20 # nobody pressed anything: back to peekaboo
  end

  def drift(dt)
    @rays.style(rotate: (@clock * 6).round(1) % 360) if @frame % 3 == 0
    @clouds.each do |c|
      c[:x] += c[:speed] * dt
      c[:x] = -c[:w] - 10.0 if c[:x] > W + 10
      at = c[:x].round
      place(c[:slot], at, c[:y]) unless at == c[:shown]
      c[:shown] = at
    end
  end

  # ---------------------------------------------------------------- building the meadow

  @sounds = MoleSounds.new
  @round_font = (ROUND_FONT_FILE && font(ROUND_FONT_FILE)&.first) || "Arial Rounded MT Bold"
  @frame = 0
  @clock = 0.0
  @next_pop = 1.0
  @stars = 0
  @hat_turn = 0
  @flying = []
  @bits = []
  @labels = []
  @propellers = {}
  @spin = {}
  @big_kid = false
  @best = load_best

  sky
  # the sun's path across the sky, shown in Big kid mode as the round's clock
  @sun_path = (0..24).map do |i|
    x, y = sun_at(i / 24.0)
    oval x, y, 6, center: true, fill: rgb(255, 255, 255, 0.75), stroke: rgb(0, 0, 0, 0), hidden: true
  end
  land
  @moles = HOLES.each_with_index.map do |(x, y, scale, note), i|
    Mole.new(x: x, y: y, scale: scale, note: note, hat: HATS[i], state: :down, time: 0.0, stay: 0.0,
      offset: WINDOW_H * scale, shown: nil, golden: false)
  end
  # back holes first, so the front ones stand in front of them
  @moles.sort_by(&:y).each { |m| mound(m) }
  @top_layer = stack(left: 0, top: 0, width: W, height: H) {}

  buttons
  @stars_box = stack(left: 0, top: 0, width: W, height: 100) { star_row }
  @score_box = stack(left: W / 2 - 110, top: 14, width: 220, height: 76, hidden: true) do
    background rgb(255, 255, 255, 0.65), curve: 30
    nostroke
    fill "#a57e5f"
    oval 44, 38, 44, 48, center: true
    fill "#ffb3c1"
    oval 44, 44, 16, 11, center: true
    fill INK
    shape { round_outline(36, 32, 6, 8); round_outline(52, 32, 6, 8) }
    @score_text = para "0", font: @round_font, size: 38, weight: "bold", stroke: "#5b4b8a", margin: [84, 8, 0, 0]
  end
  @count_box = stack(left: W / 2 - 110, top: 180, width: 220, height: 180, hidden: true) do
    background rgb(255, 255, 255, 0.8), curve: 50
    @count_text = para "3", font: @round_font, size: 96, weight: "bold", stroke: "#5b4b8a", align: "center", margin: [0, 16, 0, 0]
  end

  # the trophy card at the end of a Big kid round
  @card = stack(left: CARD[0], top: CARD[1], width: CARD[2], height: CARD[3], hidden: true) do
    background rgb(255, 250, 240, 0.97), curve: 40
    border "#f0c36d", strokewidth: 4, curve: 40
    nostroke
    fill "#ffe066".."#f59f00"
    @cup = [
      shape { move_to 170, 60; line_to 290, 60; curve_to 290, 140, 260, 170, 230, 172; curve_to 200, 170, 170, 140, 170, 60 },
      rect(218, 170, 24, 30),
      rect(186, 198, 88, 22, curve: 8),
    ]
    stroke "#f59f00"
    strokewidth 9
    nofill
    @handles = [arc(142, 70, 50, 56, 1.4, 4.9), arc(268, 70, 50, 56, -1.75, 1.75)]
    nostroke
    fill rgb(255, 255, 255, 0.55)
    shape { move_to 186, 72; curve_to 186, 110, 196, 140, 212, 154; curve_to 200, 130, 196, 100, 198, 72 }
    fill "#ffffff"
    shape { star_outline(230, 110, 22, 10) }
    # (each text is placed where it goes: in a stack, paras otherwise follow one another down)
    @medal_text = para "Gold!", font: @round_font, size: 26, weight: "bold", stroke: "#c77d00", align: "center", left: 0, top: 230, width: CARD[2]
    @trophy_stars = [-1, 0, 1].map { |i| star(230 + i * 44, 298, 5, 18, 8, fill: "#ffe066".."#fab005", stroke: "#e8a200", strokewidth: 1.5) }
    @final_text = para "0", font: @round_font, size: 54, weight: "bold", stroke: "#5b4b8a", align: "center", left: 0, top: 316, width: CARD[2]
    @best_text = para "Best: 0", font: @round_font, size: 18, stroke: "#8a7aa8", align: "center", left: 0, top: 390, width: CARD[2]
    @again = stack(left: AGAIN[0] - CARD[0], top: AGAIN[1] - CARD[1], width: AGAIN[2], height: AGAIN[3]) do
      background "#7bd389", curve: 26
      stroke "#ffffff"
      strokewidth 5
      nofill
      cap :curve
      arc 22, 17, 32, 32, 0.6, 5.6
      nostroke
      fill "#ffffff"
      shape { move_to 48, 18; line_to 56, 30; line_to 44, 30 }
      para "Again", font: @round_font, size: 22, weight: "bold", stroke: "#ffffff", margin: [66, 17, 0, 0]
    end
    @home = stack(left: HOME[0] - CARD[0], top: HOME[1] - CARD[1], width: HOME[2], height: HOME[3]) do
      background "#b197fc", curve: 26
      nostroke
      fill "#a57e5f"
      oval 38, 36, 34, 38, center: true
      fill "#ffb3c1"
      oval 38, 41, 12, 8, center: true
      fill INK
      shape { round_outline(32, 30, 5, 6); round_outline(44, 30, 5, 6) }
      para "Moles", font: @round_font, size: 22, weight: "bold", stroke: "#ffffff", margin: [66, 17, 0, 0]
    end
  end

  @leave_card = stack(left: W / 2 - 190, top: 100, width: 380, height: 70, hidden: true) do
    background rgb(61, 43, 31, 0.8), curve: 35
    nofill
    stroke rgb(255, 255, 255, 0.25)
    strokewidth 6
    oval 38, 35, 40, center: true
    stroke "#ffd43b"
    cap :curve
    @leave_ring = arc 18, 15, 40, 40, -Math::PI / 2, -Math::PI / 2 + 0.1
    para "Keep holding Esc to leave", font: @round_font, size: 17, stroke: white, margin: [76, 22, 0, 0]
  end

  click { |_button, x, y| press(x, y) }
  motion { |x, y| wiggle(x, y) }
  leave { @pointer = nil }
  keypress { |key| key_down(key) }

  animate(FPS) { tick(1.0 / FPS) }
end
