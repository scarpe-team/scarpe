# Balloon Pop: balloons float up from behind the hill, and every tap pops one.
# For ages 2 and up, with a counting game for 4 and up.
#
# Click anywhere, or press any key, and the nearest balloon pops into confetti
# and sings its note. Tap right on a balloon and it pops at once; tap somewhere
# else and a little star flies over and pops the nearest one for you. There is
# no way to lose: balloons that float away just float away, and more keep coming.
#
# Each colour has its own note and its own picture (a heart, a smile, a star,
# spots, a moon or a flower), so the colours are never the only way to tell
# them apart. Now and then a golden balloon drifts by.
#
# The 123 switch at the top turns on counting: big numbers count each pop from
# 1 to 10, climbing up the scale as they go, and at 10 there is a party. Every
# party earns a star, and the balloons rise a little quicker each round.
#
# For grown-ups: the speaker turns the sound off and on, and holding Escape for
# two seconds closes the window (Cmd-Q works too). Nothing is saved and nothing
# leaves the computer.
#
# The sounds are made right here in plain Ruby, written once to small WAV files
# and played with afplay. Every note is from the same five-note (pentatonic)
# scale, so any pops in any order sound like a tune.

require "tmpdir"
require "fileutils"

W, H = 960, 640
FPS = 30
BAR_LEFT = 230 # where the counting bar starts

# Six kinds of balloon: a colour (light, then deep), a picture and a note.
KINDS = [
  { name: :heart, light: "#ff8f8a", deep: "#ec3f45", note: "c5" },
  { name: :smile, light: "#ffc27a", deep: "#fb8a26", note: "d5" },
  { name: :star, light: "#fff59a", deep: "#f2d50f", note: "e5" },
  { name: :spots, light: "#8ee6a2", deep: "#2fb35c", note: "g5" },
  { name: :moon, light: "#8cc8ff", deep: "#2f86e8", note: "a5" },
  { name: :flower, light: "#cfa8ff", deep: "#8a5ae6", note: "c6" },
]
GOLD = { name: :star, light: "#ffe9a3", deep: "#e39200", note: "g6", gold: true }
COUNTING_NOTES = %w[c5 d5 e5 g5 a5 c6 d6 e6 g6 a6] # the count climbs the scale

# Fredoka, the round font the Kids apps share. It travels with the app (in fonts,
# loose beside it, or in _fonts), and in a Scarpe checkout it sits in the _fonts
# folder next door: the same four places every Kids app looks. Without it, the
# words still show in a fallback face.
FREDOKA = %w[fonts . _fonts ../_fonts].map { |dir| File.expand_path("#{dir}/Fredoka.ttf", __dir__) }.find { |path| File.exist?(path) }
ROUND = (FREDOKA && font(FREDOKA)&.first) || "Arial Rounded MT Bold, Helvetica, sans-serif"

Balloon = Struct.new(:kind, :x, :y, :w, :h, :home, :sway, :phase, :speed, :parts, :strings, :lean, :aimed)
Bit = Struct.new(:art, :x, :y, :vx, :vy, :spin, :turn, :age, :life, :color) # confetti, sparkles and friends

# The sounds. Each is worked out once as a list of numbers, written to a WAV
# file once, and handed to afplay whenever it is wanted.
class Sounds
  RATE = 22_050
  LOUDEST = 0.3 # the peak of any sound, where 1.0 would be as loud as a WAV can go
  AT_ONCE = 6   # however fast the pops come, no more than this many sounds at the same moment
  NOTES = %w[c c# d d# e f f# g g# a a# b]

  attr_reader :last_file, :player
  attr_accessor :muted

  def initialize
    @dir = Dir.mktmpdir("balloon-pop")
    at_exit { FileUtils.rm_rf(@dir) }
    @files = {}
    @playing = []
    @noise = Random.new(3)
  end

  # play(:pop, "e5"), or play(:party) for the ones that need no note.
  def play(voice, note = nil)
    return if muted

    @playing.select!(&:alive?)
    return if @playing.size >= AT_ONCE

    name = [voice, note].compact.join("-")
    @last_file = @files[name] ||= write(name, loudest(note ? send(voice, hz(note)) : send(voice)))
    @player = Process.detach(spawn("afplay", @last_file, out: File::NULL, err: File::NULL))
    @playing << @player
  rescue SystemCallError
    # no afplay here (not a Mac): the balloons pop in silence
  end

  private

  # A pop: a soft puff of air, then the balloon's note on a little marimba.
  def pop(hz)
    mix([puff, marimba(hz, 0.03)])
  end

  # A marimba bar: its note, plus a ring four times higher that dies away fast.
  def marimba(hz, delay = 0.0)
    silence(delay) + sound(0.9) do |t|
      (wave(hz, t) + 0.25 * wave(hz * 4, t) * Math.exp(-t * 18)) * Math.exp(-t * 6) * rise(t, 0.004)
    end
  end

  # A puff: noise, softened by averaging each sample with the ones before it.
  def puff
    soft = 0.0
    sound(0.07) do |t|
      soft += ((@noise.rand * 2 - 1) - soft) * 0.25
      1.6 * soft * Math.exp(-t * 60) * rise(t, 0.002)
    end
  end

  # The party: four notes up, then a sparkle of high ones, all on the marimba.
  def party
    notes = [["c5", 0.0], ["e5", 0.12], ["g5", 0.24], ["c6", 0.36], ["e6", 0.62], ["g6", 0.74], ["c7", 0.86]]
    mix(notes.map { |note, at| marimba(hz(note), at) })
  end

  # Switching modes: two quick notes, up into counting or down out of it.
  def up
    mix([marimba(hz("g5")), marimba(hz("c6"), 0.1)])
  end

  def down
    mix([marimba(hz("c6")), marimba(hz("g5"), 0.1)])
  end

  def tick
    marimba(hz("g6"))
  end

  def wave(hz, t) = Math.sin(2 * Math::PI * hz * t)

  # How far a sound has faded in, so none of them starts with a click.
  def rise(t, seconds) = [t / seconds, 1].min

  def silence(seconds) = Array.new((RATE * seconds).round, 0.0)

  # `seconds` of sound: one number for each moment t, the last hundredth of a second fading out.
  def sound(seconds)
    Array.new((RATE * seconds).round) do |i|
      t = i.fdiv(RATE)
      yield(t) * [(seconds - t) * 100, 1].min
    end
  end

  # Sounds laid over each other, sample by sample.
  def mix(parts)
    out = Array.new(parts.map(&:size).max, 0.0)
    parts.each { |part| part.each_with_index { |sample, i| out[i] += sample } }
    out
  end

  # Every sound is scaled so its loudest moment is LOUDEST: nothing here is ever loud.
  def loudest(samples)
    top = samples.map(&:abs).max
    samples.map { |sample| sample * LOUDEST / top }
  end

  # "a4" is 440 Hz, and each semitone up is the twelfth root of two higher.
  def hz(note)
    semitones = NOTES.index(note[/\D+/]) + 12 * (note[/\d+/].to_i + 1) - 69
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

Shoes.app(title: "Balloon Pop", width: W, height: H, resizable: false) do
  # ---------------------------------------------------------------- drawing kit

  # A slot or a text block reads a number from 0 to 1 as a fraction of its
  # parent, so anything moved to such a spot goes to a whole pixel instead. (It
  # reads a negative number as that far in from the far edge, which is why the
  # big numbers stay inside the window, and why balloons and clouds are shapes.)
  def px(v)
    v > 0 && v <= 1 ? v.round : v.round(1)
  end

  def ease_out(k) = 1 - (1 - k.clamp(0.0, 1.0))**3

  # Overshoots a little and settles back, like something springing into place.
  def spring(k)
    k = k.clamp(0.0, 1.0)
    1 + 2.7 * (k - 1)**3 + 1.7 * (k - 1)**2
  end

  # The tops of the two hills, at any x across the window.
  def far_hill(x) = 488 + 18 * Math.sin(x / 190.0 + 0.7) + 6 * Math.sin(x / 80.0)
  def near_hill(x) = 540 + 16 * Math.sin(x / 150.0 + 2.2) + 5 * Math.sin(x / 60.0 + 1)

  # A hill: its top follows the function, every 16 pixels, down to the bottom of the window.
  def hill(&top)
    shape do
      move_to 0, top.call(0)
      (16..W).step(16) { |x| line_to x, top.call(x) }
      line_to W, H
      line_to 0, H
    end
  end

  # A fluffy cloud w wide: round puffs on a flat bottom, all one shape. (One
  # shape, not a slot, so it can hang off the left edge as it drifts back in.)
  def cloud(x, y, w)
    h = w * 0.42
    shape(left: x, top: y) do
      move_to w * 0.14, h
      line_to w * 0.86, h
      curve_to w * 0.99, h, w * 0.99, h * 0.5, w * 0.86, h * 0.48
      curve_to w * 0.88, h * 0.12, w * 0.68, h * 0.1, w * 0.64, h * 0.3
      curve_to w * 0.62, h * -0.2, w * 0.38, h * -0.2, w * 0.36, h * 0.26
      curve_to w * 0.3, h * 0.02, w * 0.1, h * 0.1, w * 0.15, h * 0.5
      curve_to w * 0.01, h * 0.52, w * 0.01, h, w * 0.14, h
    end
  end

  # ---------------------------------------------------------------- balloons

  # A balloon's body, w wide and h tall: round at the top, narrowing to its knot.
  def balloon_body(left, w, h)
    shape(left: left, top: 0) do
      move_to w * 0.5, 0
      curve_to w * 0.79, 0, w, h * 0.21, w, h * 0.46
      curve_to w, h * 0.74, w * 0.7, h * 0.94, w * 0.5, h
      curve_to w * 0.3, h * 0.94, 0, h * 0.74, 0, h * 0.46
      curve_to 0, h * 0.21, w * 0.21, 0, w * 0.5, 0
    end
  end

  # The picture on a balloon, around (cx, cy) and about s across.
  def picture(kind, cx, cy, s)
    nostroke
    fill rgb(255, 255, 255, 0.88)
    case kind[:name]
    when :heart
      shape do
        move_to cx, cy + s * 0.42
        curve_to cx - s * 0.62, cy, cx - s * 0.5, cy - s * 0.46, cx, cy - s * 0.18
        curve_to cx + s * 0.5, cy - s * 0.46, cx + s * 0.62, cy, cx, cy + s * 0.42
      end
    when :smile
      fill rgb(140, 64, 18, 0.75)
      oval cx - s * 0.2, cy - s * 0.1, s * 0.13, s * 0.17, center: true
      oval cx + s * 0.2, cy - s * 0.1, s * 0.13, s * 0.17, center: true
      nofill
      stroke rgb(140, 64, 18, 0.75)
      strokewidth 3
      cap :curve
      shape { move_to cx - s * 0.26, cy + s * 0.12; curve_to cx - s * 0.12, cy + s * 0.32, cx + s * 0.12, cy + s * 0.32, cx + s * 0.26, cy + s * 0.12 }
      nostroke
      fill rgb(255, 120, 90, 0.4)
      oval cx - s * 0.36, cy + s * 0.08, s * 0.16, s * 0.1, center: true
      oval cx + s * 0.36, cy + s * 0.08, s * 0.16, s * 0.1, center: true
    when :star
      star cx, cy, 5, s * 0.5, s * 0.22
    when :spots
      [[-0.26, -0.18, 0.34], [0.24, -0.04, 0.28], [-0.04, 0.3, 0.3], [0.3, -0.42, 0.16], [-0.44, 0.22, 0.14]].each do |dx, dy, d|
        oval cx + s * dx, cy + s * dy, s * d, center: true
      end
    when :moon
      shape do
        move_to cx + s * 0.1, cy - s * 0.42
        curve_to cx - s * 0.46, cy - s * 0.36, cx - s * 0.46, cy + s * 0.36, cx + s * 0.1, cy + s * 0.42
        curve_to cx - s * 0.18, cy + s * 0.24, cx - s * 0.18, cy - s * 0.24, cx + s * 0.1, cy - s * 0.42
      end
    when :flower
      5.times do |i|
        a = -Math::PI / 2 + i * 2 * Math::PI / 5
        oval cx + Math.cos(a) * s * 0.22, cy + Math.sin(a) * s * 0.22, s * 0.26, center: true
      end
      fill rgb(255, 214, 90, 0.95)
      oval cx, cy, s * 0.2, center: true
    end
  end

  # A balloon's string, hanging from (x, y) with a little wave in it; `lean` is how
  # far its end trails to one side. Each balloon has three, and shows the one that
  # matches how it is swaying, rather than turning one string round.
  def string(x, y, lean)
    bend = ->(dy) { x + lean * (dy / 128.0)**2 }
    shape do
      move_to bend.(0), y
      curve_to bend.(28) + 6, y + 28, bend.(58) - 6, y + 58, bend.(86), y + 86
      curve_to bend.(104) + 5, y + 104, bend.(116) - 3, y + 116, bend.(128), y + 128
    end
  end

  # A new balloon, somewhere along the bottom, out of sight behind the hill.
  #
  # A balloon is a handful of shapes rather than a slot, because it has to float
  # right out of the top of the window and a slot can't: Shoes reads a negative
  # top on a slot as "that far up from the bottom". So each piece is drawn where
  # it sits on the balloon (as if the balloon's corner were at 0, 0), remembers
  # that place, and every frame all the pieces move together.
  def launch(kind = nil, x: nil, speed: 1.0)
    kind ||= rand < 0.06 ? GOLD : KINDS.sample
    w = kind[:gold] ? 104 : rand(78..94)
    h = (w * 1.18).round
    x ||= spare_x(w)
    b = Balloon.new(kind, x.to_f, H + 10.0, w, h, x.to_f, rand(14.0..26.0), rand * 6, rand(44.0..58.0) * speed * @pace)
    drawn = @sky.contents.size
    @sky.append { b.strings = draw_balloon(kind, w, h) }
    b.parts = @sky.contents.drop(drawn).map { |art| [art, art.left, art.top] }
    b.lean = 1
    place(b)
    @balloons << b
    b
  end

  def draw_balloon(kind, w, h)
    nostroke
    fill kind[:light]..kind[:deep]
    if kind[:gold] # the golden balloon wears a white rim, so it stands out by more than its colour
      stroke rgb(255, 255, 255, 0.95)
      strokewidth 3
    end
    balloon_body(0, w, h)
    nostroke
    fill kind[:deep]
    shape { move_to w / 2.0 - 6, h + 8; line_to w / 2.0 + 6, h + 8; line_to w / 2.0, h - 3 }
    picture(kind, w / 2.0, h * 0.46, w * 0.42)
    fill rgb(255, 255, 255, 0.5) # its shine: a tilted leaf of light
    shape do
      move_to w * 0.2, h * 0.38
      curve_to w * 0.13, h * 0.26, w * 0.24, h * 0.1, w * 0.36, h * 0.11
      curve_to w * 0.42, h * 0.17, w * 0.31, h * 0.33, w * 0.2, h * 0.38
    end
    fill rgb(255, 255, 255, 0.6)
    oval w * 0.19, h * 0.46, w * 0.06, center: true
    if kind[:gold]
      fill rgb(255, 255, 255, 0.95)
      star w * 0.84, h * 0.14, 4, 11, 3.5
      star w * 0.1, h * 0.68, 4, 7, 2.2
      star w * 0.9, h * 0.62, 4, 6, 2
    end
    nofill
    stroke rgb(96, 96, 120, 0.7)
    strokewidth 1.6
    strings = [-12, 0, 12].map { |lean| string(w / 2.0, h + 8, lean) }
    strings.values_at(0, 2).each(&:hide)
    strings
  end

  # Moves every piece of a balloon to where the balloon is now. A string that
  # isn't showing stays where it is until its turn.
  def place(b)
    left, top = b.x - b.w / 2.0, b.y
    b.parts.each do |art, dx, dy|
      art.style(left: (left + dx).round(1), top: (top + dy).round(1)) unless art.hidden
    end
  end

  def unmake(b)
    b.parts.each { |art, _, _| art.remove }
  end

  # Somewhere along the bottom that is not right under another new balloon.
  def spare_x(w)
    tries = Array.new(8) { rand(w..W - w).to_f }
    tries.max_by { |x| @balloons.map { |b| (b.home - x).abs + (b.y > H - 200 ? 0 : 200) }.min || W }
  end

  def float_balloons(dt)
    @balloons.each do |b|
      b.y -= b.speed * (seen?(b) ? 1 : 3) * dt
      b.x = b.home + Math.sin(@clock * 0.9 + b.phase) * b.sway
      lean = -Math.cos(@clock * 0.9 + b.phase) # which way the string trails
      shown = lean < -0.5 ? 0 : (lean > 0.5 ? 2 : 1)
      if shown != b.lean
        b.strings[b.lean].hide
        b.strings[shown].show
        b.lean = shown
      end
      place(b)
    end
    gone = @balloons.select { |b| b.y < -b.h - 150 }
    gone.each { |b| unmake(b) }
    @balloons -= gone
  end

  # New balloons come up whenever there are too few still to play with. One
  # that is drifting out of the top doesn't count: it is on its way home.
  def keep_them_coming(dt)
    @since_launch += dt
    wanted = @party ? 10 : (@counting ? 6 : 8)
    playing = @balloons.count { |b| b.y > 60 }
    return if playing >= wanted || @since_launch < (playing < 3 ? 0.2 : 0.6)

    @since_launch = 0
    launch(speed: @party ? 2.2 : 1.0)
  end

  def centre(b) = [b.x, b.y + b.h * 0.45]

  def seen?(b) = b.y + b.h * 0.3 < near_hill(b.x)

  # The balloon under a point, if one is; otherwise the nearest one in sight
  # (or, when none is in sight yet, the one closest to coming over the hill).
  def balloon_near(x, y)
    free = @balloons.reject(&:aimed)
    under = free.find { |b| cx, cy = centre(b); ((x - cx) / (b.w * 0.5 + 10))**2 + ((y - cy) / (b.h * 0.5 + 10))**2 <= 1 }
    return [under, true] if under

    seen = free.select { |b| seen?(b) }
    pick = seen.min_by { |b| cx, cy = centre(b); Math.hypot(cx - x, cy - y) } || free.min_by(&:y)
    [pick, false]
  end

  # ---------------------------------------------------------------- popping

  def poke(x, y)
    b, under = balloon_near(x, y)
    return sparkle_at(x, y) unless b
    return pop(b) if under

    b.aimed = true
    thrown = @throws.find { |t| t[:b].nil? } || @throws.max_by { |t| t[:age] }
    pop(thrown[:b]) if thrown[:b] # still flying: its balloon pops at once, so none is left waiting
    thrown.merge!(b: b, from: [x, y], age: 0.0)
    thrown[:art].show
  end

  def fly_throws(dt)
    @throws.each do |t|
      next unless t[:b]

      t[:age] += dt
      k = ease_out(t[:age] / 0.2)
      tx, ty = centre(t[:b])
      t[:art].move(px(t[:from][0] + (tx - t[:from][0]) * k), px(t[:from][1] + (ty - t[:from][1]) * k))
      t[:art].style(outer: (13 + 3 * Math.sin(t[:age] * 40)).round(1))
      next if k < 1

      pop(t[:b]) if @balloons.include?(t[:b])
      t[:b] = nil
      t[:art].hide
    end
  end

  def pop(b)
    return unless @balloons.delete(b)

    unmake(b)
    cx, cy = centre(b)
    burst(cx, cy, b.kind)
    ring(cx, cy, b.kind[:deep])
    drop_string(cx, b.y + b.h + 8)
    if @counting && !@party
      count_up(b, cx, cy)
    else
      @sounds.play(:pop, b.kind[:note])
    end
    shower(cx, cy) if b.kind[:gold]
    @sun_grin = 1.0
  end

  # ---------------------------------------------------------------- confetti and sparkles

  def pools
    nostroke
    @confetti = Array.new(90) { Bit.new(rect(0, 0, 10, 6, curve: 1.5, hidden: true)) }
    @sparkles = Array.new(24) { Bit.new(star(0, 0, 4, 8, 2.6, fill: white, hidden: true)) }
    @strings = Array.new(4) do
      nofill
      stroke rgb(96, 96, 120, 0.7)
      strokewidth 1.6
      Bit.new(shape { move_to 0, 0; curve_to 6, 28, -6, 58, 0, 86; curve_to 5, 104, -3, 116, 0, 128 }.tap(&:hide))
    end
    nofill
    strokewidth 4
    @rings = Array.new(4) { Bit.new(oval(0, 0, 20, center: true, hidden: true)) }
    nostroke
    fill "#fff2a8".."#ffcc33"
    stroke rgb(255, 255, 255, 0.9)
    strokewidth 2
    @throws = Array.new(4) { { art: star(0, 0, 5, 13, 6, hidden: true), b: nil } }
  end

  def take(pool)
    bit = pool.find { |b| b.age.nil? || b.age >= b.life } || pool.min_by { |b| b.life - b.age }
    bit.age = 0.0
    bit
  end

  def burst(x, y, kind)
    colors = [kind[:deep], kind[:light], "#ffffff", "#ffd84d"]
    14.times do |i|
      bit = take(@confetti)
      angle = rand * 2 * Math::PI
      speed = rand(120.0..300.0)
      bit.x, bit.y, bit.vx, bit.vy = x, y, Math.cos(angle) * speed, Math.sin(angle) * speed - 120
      bit.spin, bit.turn, bit.life, bit.color = rand(-600.0..600.0), rand(0..180), rand(1.0..1.5), colors[i % 4]
      bit.art.style(fill: bit.color, hidden: false)
    end
    6.times do |i|
      bit = take(@sparkles)
      angle = i * Math::PI / 3 + rand * 0.5
      bit.x, bit.y, bit.vx, bit.vy, bit.life = x, y, Math.cos(angle) * 160, Math.sin(angle) * 160, 0.7
      bit.art.show
    end
  end

  # Confetti from the top, all across the window: for parties and golden balloons.
  def shower(x = nil, y = nil, count: 30)
    colors = KINDS.map { |k| k[:deep] } + ["#ffffff", "#ffd84d"]
    count.times do |i|
      bit = take(@confetti)
      bit.x = x ? x + rand(-160.0..160.0) : rand(0.0..W)
      bit.y = y ? y - rand(60.0..200.0) : rand(-300.0..-10.0)
      bit.vx, bit.vy = rand(-40.0..40.0), rand(40.0..110.0)
      bit.spin, bit.turn, bit.life, bit.color = rand(-300.0..300.0), rand(0..180), rand(3.0..4.5), colors[i % colors.size]
      bit.art.style(fill: bit.color, hidden: false)
    end
  end

  def ring(x, y, color)
    bit = take(@rings)
    bit.x, bit.y, bit.life, bit.color = x, y, 0.4, color
    bit.art.style(left: x, top: y, width: 20, height: 20, stroke: color, hidden: false)
  end

  def drop_string(x, y)
    bit = take(@strings)
    bit.x, bit.y, bit.vx, bit.vy, bit.life = x, y, rand(-20.0..20.0), -40, 1.2
    bit.art.show
  end

  def sparkle_at(x, y)
    3.times do |i|
      bit = take(@sparkles)
      angle = i * 2.1 + rand
      bit.x, bit.y, bit.vx, bit.vy, bit.life = x, y, Math.cos(angle) * 60, Math.sin(angle) * 60, 0.6
      bit.art.show
    end
  end

  # Everything flying about: confetti tumbles and falls, sparkles fly out and
  # shrink away, rings spread, strings drop.
  def fly_bits(dt)
    @confetti.each do |bit|
      next if bit.age.nil? || bit.age >= bit.life

      bit.age += dt
      next bit.art.hide if bit.age >= bit.life

      bit.vy += 420 * dt
      bit.vy = [bit.vy, 160].min if bit.life > 2 # party confetti floats down gently
      bit.vx *= 0.97
      bit.x += (bit.vx + Math.sin(bit.age * 4 + bit.turn) * 30) * dt
      bit.y += bit.vy * dt
      bit.turn += bit.spin * dt
      flat = (1 + 5 * Math.cos(bit.turn * Math::PI / 180).abs).round # a tumbling scrap of paper
      bit.art.style(left: px(bit.x), top: px(bit.y - flat / 2.0), height: flat)
    end
    @sparkles.each do |bit|
      next if bit.age.nil? || bit.age >= bit.life

      bit.age += dt
      next bit.art.hide if bit.age >= bit.life

      bit.x += bit.vx * dt
      bit.y += bit.vy * dt
      bit.vx *= 0.9
      bit.vy *= 0.9
      fade = 1 - bit.age / bit.life
      bit.art.style(left: px(bit.x), top: px(bit.y), outer: (8 * fade + 2).round(1), inner: (2.6 * fade + 0.8).round(1),
        fill: rgb(255, 255, 240, fade.round(2)))
    end
    @rings.each do |bit|
      next if bit.age.nil? || bit.age >= bit.life

      bit.age += dt
      next bit.art.hide if bit.age >= bit.life

      k = bit.age / bit.life
      d = (20 + 110 * ease_out(k)).round
      bit.art.style(width: d, height: d, strokewidth: (5 * (1 - k)).round(1) + 0.5)
    end
    @strings.each do |bit|
      next if bit.age.nil? || bit.age >= bit.life

      bit.age += dt
      next bit.art.hide if bit.age >= bit.life

      bit.vy += 300 * dt
      bit.x += bit.vx * dt
      bit.y += bit.vy * dt
      bit.art.style(left: px(bit.x), top: px(bit.y), stroke: rgb(96, 96, 120, (0.7 * (1 - bit.age / bit.life)).round(2)))
    end
  end

  # ---------------------------------------------------------------- counting

  # The counting bar: ten places, each with its number waiting in it faintly,
  # and a shelf beneath for the stars that parties earn.
  def counter
    @bar = stack(left: BAR_LEFT, top: 18, width: 500, height: 64, hidden: true) do
      background rgb(255, 255, 255, 0.55), curve: 32
      @places = Array.new(10) do |i|
        x = 34 + i * 48
        nostroke
        disc = oval x, 32, 40, center: true, fill: rgb(255, 255, 255, 0.7)
        label = para (i + 1).to_s, font: ROUND, size: 17, weight: "bold", align: "center",
          stroke: rgb(90, 110, 150, 0.45), left: x - 20, top: 19, width: 40, margin: 0
        { disc: disc, label: label, x: x, filled: false }
      end
    end
    @shelf = stack(left: BAR_LEFT, top: 86, width: 500, height: 30, hidden: true) {}
  end

  def shelve_stars
    @shelf.clear do
      stroke rgb(255, 255, 255, 0.95)
      strokewidth 1.5
      fill "#ffcc33"
      [@round, 12].min.times { |i| star 250 + (i - ([@round, 12].min - 1) / 2.0) * 26, 14, 5, 11, 5 }
    end
  end

  def count_up(b, cx, cy)
    @count += 1
    @sounds.play(:pop, COUNTING_NOTES[@count - 1])
    big = @numbers.find { |n| n[:age].nil? } || @numbers.max_by { |n| n[:age] }
    land(big) if big[:age] # still flying: it lands at once, so no number is ever skipped
    big.merge!(age: 0.0, n: @count, from: [cx.clamp(130, W - 130), cy.clamp(90, 430)], color: b.kind[:deep]) # a slot can't go above the window
    big[:front].replace(@count.to_s)
    big[:back].replace(@count.to_s)
    big[:back].style(stroke: b.kind[:deep])
    big[:slot].show
    return unless @count == 10

    @party = 0.0
  end

  # The big numbers: spring up where the balloon was, then fly into their place.
  def numerals
    @numbers = Array.new(5) do
      front = back = nil
      slot = stack(left: 0, top: 0, width: 240, height: 170, hidden: true) do
        back = para "", font: ROUND, size: 110, weight: "bold", align: "center", stroke: "#ec3f45", left: 5, top: 7, width: 240, margin: 0
        front = para "", font: ROUND, size: 110, weight: "bold", align: "center", stroke: white, left: 0, top: 0, width: 240, margin: 0
      end
      { slot: slot, front: front, back: back, age: nil }
    end
  end

  def fly_numerals(dt)
    @numbers.each do |big|
      next unless big[:age]

      big[:age] += dt
      target = @places[big[:n] - 1]
      if big[:age] < 0.7
        size = 110 * spring(big[:age] / 0.35)
        x, y = big[:from]
      else
        k = ease_out((big[:age] - 0.7) / 0.4)
        size = 110 + (22 - 110) * k
        x = big[:from][0] + (BAR_LEFT + target[:x] - big[:from][0]) * k
        y = big[:from][1] + (18 + 32 - big[:from][1]) * k
      end
      size = [size, 8].max.round
      big[:slot].move(px(x - 120), px(y - size * 0.72))
      [big[:front], big[:back]].each { |para| para.style(size: size) }
      land(big) if big[:age] >= 1.1
    end
  end

  def land(big)
    big[:age] = nil
    big[:slot].hide
    fill_place(@places[big[:n] - 1], big[:color])
  end

  def fill_place(place, color)
    place[:filled] = true
    place[:disc].style(fill: color)
    place[:label].style(stroke: white)
    place[:hop] = 0.0
  end

  def empty_places
    @places.each do |place|
      place[:filled] = false
      place[:disc].style(fill: rgb(255, 255, 255, 0.7), top: 32)
      place[:label].style(stroke: rgb(90, 110, 150, 0.45), top: 19)
    end
  end

  def hop_places(dt)
    @places.each do |place|
      next unless place[:hop]

      place[:hop] += dt
      lift = place[:hop] < 0.3 ? 10 * Math.sin(Math::PI * place[:hop] / 0.3) : 0
      place[:disc].style(top: (32 - lift).round(1))
      place[:label].style(top: (19 - lift).round(1))
      place[:hop] = nil if place[:hop] >= 0.3
    end
  end

  # At ten: a fanfare, confetti from the sky, a big gold star, a flight of
  # balloons, every place hopping in turn, and a star for the shelf.
  def party(dt)
    return unless @party

    was = @party
    @party += dt
    if was.zero?
      @sounds.play(:party)
      shower(count: 70)
      @cheer = 0.0
    end
    @places.each_with_index { |place, i| place[:hop] = 0.0 if was < 1.2 + i * 0.07 && @party >= 1.2 + i * 0.07 }
    k = @party < 0.5 ? spring(@party / 0.5) : (@party > 2.4 ? [1 - (@party - 2.4) / 0.4, 0].max : 1)
    @trophy[:slot].style(hidden: k <= 0.02)
    @trophy[:star].style(outer: (150 * k).round(1), inner: (66 * k).round(1), rotate: (@party * 20).round % 360)
    @trophy[:ten].style(size: [(64 * k).round, 6].max, top: (150 - 40 * k).round)
    return if @party < 4.5

    @party = nil
    @count = 0
    @round += 1
    @pace = 1 + 0.08 * [@round, 5].min
    empty_places
    shelve_stars
  end

  def trophy
    art = ten = nil
    slot = stack(left: W / 2 - 150, top: H / 2 - 170, width: 300, height: 300, hidden: true) do
      transform :center
      fill "#fff3a0".."#ffbf1f"
      stroke white
      strokewidth 6
      art = star 150, 150, 5, 150, 66
      ten = para "10", font: ROUND, size: 64, weight: "bold", align: "center", stroke: "#f08a00", left: 0, top: 110, width: 300, margin: 0
    end
    { slot: slot, star: art, ten: ten }
  end

  # ---------------------------------------------------------------- the sun, clouds, hills and flowers

  def sun
    nostroke
    [210, 170, 136].each_with_index { |d, i| oval 150, 150, d, center: true, fill: rgb(255, 236, 150, 0.12 + i * 0.06) }
    transform :center
    fill "#ffe66b"
    @rays = star 150, 150, 12, 78, 56
    fill "#fff08a".."#ffc93c"
    oval 150, 150, 104, center: true
    transform :corner
    fill "#7a4a12"
    @sun_eyes = [oval(132, 142, 10, 13, center: true), oval(168, 142, 10, 13, center: true)]
    nofill
    stroke "#7a4a12"
    strokewidth 3.5
    cap :curve
    @sun_happy = [[132, 142], [168, 142]].map { |x, y| shape { move_to x - 7, y + 2; curve_to x - 3, y - 6, x + 3, y - 6, x + 7, y + 2 } }
    @sun_happy.each(&:hide)
    @sun_smile = shape { move_to 134, 162; curve_to 142, 172, 158, 172, 166, 162 }
    nostroke
    fill "#7a4a12"
    @sun_laugh = shape { move_to 130, 160; curve_to 138, 182, 162, 182, 170, 160; line_to 130, 160 }
    @sun_laugh.hide
    fill rgb(255, 140, 110, 0.4)
    oval 122, 164, 16, 10, center: true
    oval 178, 164, 16, 10, center: true
  end

  def shine(dt)
    @sun_grin = [@sun_grin - dt * 1.5, 0].max
    @cheer = @cheer && @cheer + dt
    @cheer = nil if @cheer && @cheer > 3.5
    happy = @cheer || @sun_grin > 0.2
    if happy != @sun_was_happy
      @sun_was_happy = happy
      @sun_eyes.each { |eye| eye.hidden = happy }
      @sun_happy.each { |eye| eye.hidden = !happy }
      @sun_smile.hidden = happy
      @sun_laugh.hidden = !happy
    end
    if @cheer
      @ray_turn += dt * 60
      @rays.style(rotate: @ray_turn.round % 360) # a party: the rays spin
    elsif @ray_turn != 0
      @ray_turn = 0
      @rays.style(rotate: 0)
    else
      reach = (78 + 3 * Math.sin(@clock * 1.5)).round
      @rays.style(outer: reach) if reach != @ray_reach # the rays breathe, a pixel at a time
      @ray_reach = reach
    end
    return if happy || @pointer.nil?

    dx = ((@pointer[0] - 150) / 150.0).clamp(-3, 3).round
    dy = ((@pointer[1] - 150) / 150.0).clamp(-2, 3).round
    return if [dx, dy] == @sun_look

    @sun_look = [dx, dy]
    @sun_eyes.each_with_index { |eye, i| eye.style(left: [132, 168][i] + dx, top: 142 + dy) }
  end

  def clouds
    nostroke
    fill rgb(255, 255, 255, 0.92)
    [[380, 76, 160, 8], [640, 156, 130, 12], [60, 256, 120, 6]].map do |x, y, w, speed|
      { art: cloud(x, y, w), x: x.to_f, y: y, w: w, speed: speed }
    end
  end

  def drift(dt)
    @clouds.each do |c|
      c[:x] += c[:speed] * dt
      c[:x] = -c[:w] - 30.0 if c[:x] > W + 10
      x = c[:x].round
      c[:art].style(left: x) if x != c[:shown]
      c[:shown] = x
    end
  end

  def flowers
    colors = ["#ff8fb8", "#ffffff", "#ffd84d", "#c9a8ff", "#ff9f6b"]
    field = Random.new(9)
    Array.new(16) do |i|
      x = 30 + i * 58 + field.rand(-14..14)
      y = near_hill(x) + field.rand(22..80)
      stroke "#3f9a4a"
      strokewidth 3
      cap :curve
      stem = line x, y + 36, x, y
      head = stack(left: x - 16, top: y - 16, width: 32, height: 32) do
        nostroke
        fill colors[i % colors.size]
        5.times do |p|
          a = -Math::PI / 2 + p * 2 * Math::PI / 5
          oval 16 + Math.cos(a) * 8, 16 + Math.sin(a) * 8, 13, center: true
        end
        fill "#ffcf3f"
        oval 16, 16, 9, center: true
      end
      { head: head, stem: stem, x: x, y: y, wiggle: nil, phase: field.rand * 6 }
    end
  end

  # Flowers nod in the breeze, and wiggle when the pointer brushes past.
  def breeze(dt)
    frame = (@clock * FPS).round
    @flowers.each do |f|
      next unless frame % 3 == 0 || f[:wiggle]

      if @pointer && f[:wiggle].nil? && Math.hypot(@pointer[0] - f[:x], @pointer[1] - f[:y]) < 36
        f[:wiggle] = 0.0
      end
      lean = Math.sin(@clock * 1.2 + f[:phase]) * 2.5
      if f[:wiggle]
        f[:wiggle] += dt
        lean += 9 * Math.sin(f[:wiggle] * 14) * Math.exp(-f[:wiggle] * 3)
        f[:wiggle] = nil if f[:wiggle] > 1.5
      end
      lean = lean.round
      next if lean == f[:lean]

      f[:lean] = lean
      f[:head].move(f[:x] - 16 + lean, f[:y] - 16)
      f[:stem].style(x2: f[:x] + lean)
    end
  end

  # ---------------------------------------------------------------- the buttons

  def speaker_button
    nostroke
    fill rgb(255, 255, 255, 0.55)
    stroke rgb(255, 255, 255, 0.9)
    strokewidth 2
    oval 50, 50, 64, center: true
    nostroke
    fill "#3d5a8a"
    rect 34, 43, 9, 14, curve: 2
    shape { move_to 40, 43; line_to 52, 33; line_to 52, 67; line_to 40, 57 }
    nofill
    stroke "#3d5a8a"
    strokewidth 3
    cap :curve
    @waves = [[58, 8], [63, 15]].map do |x, r|
      shape { move_to x, 50 - r; curve_to x + r * 0.7, 50 - r * 0.6, x + r * 0.7, 50 + r * 0.6, x, 50 + r }
    end
    @hush = [line(58, 44, 70, 56), line(70, 44, 58, 56)]
    @hush.each(&:hide)
  end

  def toggle_sound
    @sounds.muted = !@sounds.muted
    @waves.each { |wave| wave.hidden = @sounds.muted }
    @hush.each { |line| line.hidden = !@sounds.muted }
    @sounds.play(:tick) unless @sounds.muted
  end

  # A switch with two halves: a balloon for popping, and 123 for counting.
  # The chosen half is white, the other see-through.
  def mode_switch
    left = W - 176
    stack(left: left, top: 18, width: 158, height: 64) do
      background rgb(255, 255, 255, 0.35), curve: 32
      border rgb(255, 255, 255, 0.9), curve: 32, strokewidth: 2
    end
    nostroke
    @pop_half = oval left + 36, 50, 56, center: true, fill: white
    @count_half = oval left + 122, 50, 56, center: true, fill: rgb(255, 255, 255, 0)
    fill "#ff8f8a".."#ec3f45"
    balloon_body(left + 26, 20, 24).style(top: 36)
    stroke rgb(96, 96, 120, 0.8)
    strokewidth 1.5
    line left + 36, 61, left + 36, 70
    stack(left: left + 90, top: 34, width: 64, height: 32) do
      para "123", font: ROUND, size: 19, weight: "bold", align: "center", stroke: "#3d5a8a", margin: 0
    end
  end

  def toggle_counting
    @counting = !@counting
    @pop_half.style(fill: @counting ? rgb(255, 255, 255, 0) : white)
    @count_half.style(fill: @counting ? white : rgb(255, 255, 255, 0))
    @bar.style(hidden: !@counting)
    @shelf.style(hidden: !@counting)
    @sounds.play(@counting ? :up : :down)
  end

  # ---------------------------------------------------------------- for grown-ups

  # Holding Escape for two seconds closes the window. A key held down repeats,
  # so the presses keep coming; a gap longer than a moment starts the count again.
  def grown_ups_corner
    stack(left: 40, top: H - 33, width: 180, height: 24) do
      para "hold esc to leave", font: ROUND, size: 12, stroke: rgb(255, 255, 255, 0.75), margin: 0
    end
    nostroke
    @hold_dots = Array.new(12) do |i|
      a = -Math::PI / 2 + i * Math::PI / 6
      oval 24 + 8 * Math.cos(a), H - 24 + 8 * Math.sin(a), 3.4, center: true, fill: rgb(255, 255, 255, 0.45)
    end
  end

  def hold_escape
    @escape_since = @clock if @escape_since.nil? || @clock - @escape_last > 0.6
    @escape_last = @clock
  end

  def watch_escape
    held = @escape_since && @clock - @escape_last <= 0.6 ? (@clock - @escape_since) / 2.0 : 0
    @escape_since = nil if held.zero?
    lit = (held * 12).floor
    if lit != @hold_lit
      @hold_lit = lit
      @hold_dots.each_with_index { |dot, i| dot.fill = i < lit ? rgb(255, 204, 51, 0.95) : rgb(255, 255, 255, 0.45) }
    end
    close if held >= 1
  end

  # ---------------------------------------------------------------- taps and keys

  def tapped(x, y)
    @played_at = @clock
    return toggle_sound if Math.hypot(x - 50, y - 50) < 34
    return toggle_counting if x.between?(W - 176, W - 18) && y.between?(18, 82)

    poke(x, y)
  end

  # Any key pops the balloon nearest the pointer (or the middle of the window).
  def pressed
    @played_at = @clock
    x, y = @pointer || [W / 2, H / 2]
    poke(x, y)
  end

  # ---------------------------------------------------------------- every frame

  # When nobody has played for a few seconds, every other frame is plenty for
  # balloons drifting up, and kinder to the computer.
  def calm?
    @clock - @played_at > 4 && @party.nil?
  end

  def tick(dt)
    @clock += dt
    keep_them_coming(dt)
    float_balloons(dt)
    fly_throws(dt)
    fly_bits(dt)
    fly_numerals(dt)
    hop_places(dt)
    party(dt)
    shine(dt)
    drift(dt)
    breeze(dt)
    watch_escape
  end

  # ---------------------------------------------------------------- building it

  @sounds = Sounds.new
  @clock = 0.0
  @balloons = []
  @since_launch = 0.0
  @counting = false
  @count = 0
  @round = 0
  @pace = 1.0
  @sun_grin = 0.0
  @ray_turn = 0.0
  @played_at = 0.0
  @last_frame = 0

  background "#7fcaf6".."#fff1dc"
  sun
  @clouds = clouds
  nostroke
  fill "#a8e28e".."#86cf78"
  hill { |x| far_hill(x) }
  @sky = stack(left: 0, top: 0, width: W, height: H) {}
  nostroke
  fill "#74c96d".."#4fae5c"
  hill { |x| near_hill(x) }
  @flowers = flowers
  pools
  @trophy = trophy
  numerals
  counter
  speaker_button
  mode_switch
  grown_ups_corner
  6.times { |i| launch(x: 110 + i * 150 + rand(-30..30)).y = 380 - i % 3 * 110 - rand(0..40) }

  click { |_button, x, y| tapped(x, y) }
  motion do |x, y|
    @pointer = [x, y]
    @played_at = @clock
  end
  leave { @pointer = nil }
  keypress do |key|
    if key == :escape
      hold_escape
    else
      @escape_since = nil
      pressed
    end
  end

  animate(FPS) do |n|
    next if n.odd? && calm?

    tick((n - @last_frame) / FPS.to_f)
    @last_frame = n
  end
end
