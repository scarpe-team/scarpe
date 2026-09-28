# Shape Sorter: a wooden box with a friendly face, hungry for shapes.
#
# Pick up a shape from the table (click it, or drag it) and put it in the hole
# it fits. The right hole swallows it with a clunk and a cheer. A wrong hole
# just boings it gently back to the table, so nothing is ever wrong for long.
# Each round brings another shape. Big kid mode gives the holes colours as
# well, so a shape has to find the hole of its own shape and its own colour,
# and every colour carries a mark too (dots or a ring), so colour is never the
# only clue.
#
# Stuck? Click a hole with empty hands and the shapes that fit it wiggle.
# Every key makes the shapes hop, and the space bar shows where the shape in
# your hand goes.
#
# For grown-ups: the speaker turns the sound off and on. Hold Esc for two
# seconds to close the app. Cmd-Q works too (no app can switch off the Mac's
# own shortcuts). Nothing is saved and nothing goes on the network.
#
# The sounds are made right here in plain Ruby: each one is worked out as
# numbers, written once as a small WAV file, and played with afplay, the Mac's
# own sound player.

require "tmpdir"
require "fileutils"

W, H = 1000, 700
FPS = 30
KINDS = %i[circle square triangle star heart]
PIECE = 88                      # a shape on the table, in pixels across
BOX_X, BOX_Y = 220, 70          # the box lives in a slot of its own, so it can hop
TABLE_TOP = 350
INK = "#3b2a22"
PLAIN = [[255, 107, 107], [255, 159, 67], [250, 196, 60], [92, 196, 112], [64, 170, 245], [150, 120, 250], [255, 118, 177]]

# Big kid colours. Each has a mark as well, so the colour is never the only clue.
TEAMS = {
  sun: { color: [255, 150, 30], mark: :dots },
  sky: { color: [50, 140, 250], mark: :ring },
}

# The corners of the shapes, around (0, 0) and about one unit from the middle.
CORNERS = {
  square: [[-0.8, -0.8], [0.8, -0.8], [0.8, 0.8], [-0.8, 0.8]],
  triangle: [[0, -1.0], [1.0, 0.72], [-1.0, 0.72]],
  star: Array.new(10) do |i|
    angle = -Math::PI / 2 + i * Math::PI / 5
    reach = i.even? ? 1.05 : 0.48
    [reach * Math.cos(angle), reach * Math.sin(angle) + 0.06]
  end,
}
ROUNDING = { square: [0.26], triangle: [0.22], star: [0.2, 0.05] }
HEART = [[:move_to, 0, 0.88], [:curve_to, -0.24, 0.66, -1, 0.2, -1, -0.28], [:curve_to, -1, -0.68, -0.72, -0.88, -0.48, -0.88],
  [:curve_to, -0.24, -0.88, -0.06, -0.72, 0, -0.52], [:curve_to, 0.06, -0.72, 0.24, -0.88, 0.48, -0.88],
  [:curve_to, 0.72, -0.88, 1, -0.68, 1, -0.28], [:curve_to, 1, 0.2, 0.24, 0.66, 0, 0.88]]

# All the sounds. No sound is louder than LOUDEST (about a quarter of full
# volume) and nothing starts with a click. While sounds are still ringing, a new
# one plays more softly, so all of them together stay under ROOM: a hand
# mashing the keys makes a gentle patter, never a din. The notes come from the
# pentatonic scale, five notes to an octave that sound lovely in any order.
class Music
  RATE = 22_050
  LOUDEST = 0.28
  ROOM = 0.42
  AT_ONCE = 5
  SOFTER = [1.0, 0.75, 0.55, 0.4, 0.3, 0.2] # the volumes a sound can be played at
  BLOCK = 0.02 # how finely we remember how loud each sound is as it plays, in seconds
  PENTATONIC = [0, 2, 4, 7, 9]
  TAU = 2 * Math::PI

  attr_reader :last_file, :player
  attr_accessor :muted

  def initialize
    @dir = Dir.mktmpdir("shape-sorter")
    at_exit { FileUtils.remove_entry(@dir, true) } # the little WAV files go when the app does
    @files = {}     # [name, volume] => its WAV file
    @shapes = {}    # name => its samples, worked out once
    @envelopes = {} # name => how loud it will still get, BLOCK by BLOCK
    @ringing = []   # the sounds playing now: when each started and ends, and how loud it was played
  end

  # Plays the sound called `name` (see #samples). `now` is the app's clock in seconds.
  def play(name, now)
    return false if muted

    @ringing.reject! { |sound| sound[:ends] <= now }
    return false if @ringing.size >= AT_ONCE
    return false if @ringing.any? { |sound| sound[:name] == name && now - sound[:start] < 0.05 } # twice at once is just louder

    samples = shape(name)
    room = (ROOM - @ringing.sum { |sound| loudness(sound, now) }) / LOUDEST
    volume = SOFTER.find { |v| v <= room }
    return false unless volume # the room is full: this one waits

    @last_file = @files[[name, volume]] ||= write("#{name}-#{(volume * 100).round}", samples, volume)
    @ringing << { name: name, start: now, ends: now + samples.size.fdiv(RATE), volume: volume }
    @player = Process.detach(spawn("afplay", @last_file, out: File::NULL, err: File::NULL))
    true
  rescue SystemCallError
    false # no afplay here (not a Mac): sort in silence
  end

  # A sound's samples, scaled so its loudest moment is LOUDEST, and, for every
  # moment as it plays, the loudest it will still get from there on.
  def shape(name)
    @shapes[name] ||= begin
      raw = samples(name)
      peak = raw.map(&:abs).max
      scaled = raw.map { |sample| sample * LOUDEST / peak }
      blocks = scaled.each_slice((RATE * BLOCK).round).map { |block| block.map(&:abs).max }
      still_to_come = 0
      @envelopes[name] = blocks.reverse.map { |loud| still_to_come = [still_to_come, loud].max }.reverse
      scaled
    end
  end

  # How loud a sound that is still playing will get from this moment on.
  def loudness(sound, now)
    @envelopes[sound[:name]][((now - sound[:start]) / BLOCK).floor].to_f * sound[:volume]
  end

  # Note 0 is middle C, and each step up is the next note of the pentatonic scale.
  def pitch(step)
    semitones = PENTATONIC[step % 5] + 12 * (step / 5)
    261.63 * 2**(semitones / 12.0)
  end

  def samples(name)
    case name
    when /\Apop(\d+)\z/ then glide(pitch($1.to_i + 5) * 0.75, pitch($1.to_i + 5), 0.22)
    when /\Ahop(\d+)\z/ then bell(pitch($1.to_i), 0.5)
    when "pick" then glide(pitch(4), pitch(7), 0.16)
    when "clunk" then mix([0, thud(0.28)], [0, knock(0.06)])
    when "cheer" then mix(*[5, 7, 8, 10].each_with_index.map { |step, i| [i * 0.07, bell(pitch(step), 0.6)] })
    when "boing" then boing(0.55)
    when "ooh" then mix([0, glide(pitch(5), pitch(7), 0.2)], [0.18, glide(pitch(7), pitch(6), 0.3)])
    when "giggle" then mix(*[9, 10, 9, 11].each_with_index.map { |step, i| [i * 0.08, bell(pitch(step), 0.25)] })
    when "hint" then mix([0, bell(pitch(8), 0.6)], [0.14, bell(pitch(10), 0.9)])
    when "tap" then bell(pitch(3), 0.35)
    when "switch" then mix([0, bell(pitch(5), 0.4)], [0.1, bell(pitch(8), 0.6)])
    when "hello" then mix([0, bell(pitch(5), 0.5)], [0.12, bell(pitch(9), 0.7)])
    when "hooray"
      up = [5, 7, 8, 10, 12, 13, 15].each_with_index.map { |step, i| [i * 0.08, bell(pitch(step), 0.7)] }
      mix(*up, [0.6, hum(pitch(0), 1.4)], [0.6, hum(pitch(2), 1.4)], [0.6, hum(pitch(3), 1.4)], [0.62, bell(pitch(10), 1.2)])
    else raise ArgumentError, "no sound called #{name}"
    end
  end

  private

  # `seconds` of sound, one sample for each moment t, eased in and out so it never clicks.
  def sound(seconds)
    count = (RATE * seconds).round
    Array.new(count) do |i|
      t = i.fdiv(RATE)
      yield(t) * [i / 220.0, 1].min * [(count - i) / 300.0, 1].min
    end
  end

  # A soft bell: a sine, with a little of the note an octave up that fades first.
  def bell(hz, seconds)
    sound(seconds) do |t|
      (Math.sin(TAU * hz * t) + 0.25 * Math.sin(TAU * 2 * hz * t) * Math.exp(-t * 9)) * Math.exp(-t * 4.5)
    end
  end

  # A warm triangle wave that swells in, for chords.
  def hum(hz, seconds)
    sound(seconds) do |t|
      wave = 2 * (2 * (hz * t % 1) - 1).abs - 1
      wave * [t * 10, 1].min * Math.exp(-t * 2)
    end
  end

  # A sine that slides from one pitch to another.
  def glide(from, to, seconds)
    phase = 0.0
    sound(seconds) do |t|
      phase += (from + (to - from) * [t / seconds * 1.6, 1].min) / RATE
      Math.sin(TAU * phase) * Math.exp(-t * 5)
    end
  end

  # A wooden thud: a low note that drops as it dies away.
  def thud(seconds)
    phase = 0.0
    sound(seconds) do |t|
      phase += (95 + 90 * Math.exp(-t * 30)) / RATE
      Math.sin(TAU * phase) * Math.exp(-t * 14)
    end
  end

  # The knock of wood on wood: a moment of noise with the hiss taken out.
  def knock(seconds)
    noise = Random.new(4)
    low = lower = 0.0
    sound(seconds) do |t|
      low += (noise.rand(-1.0..1.0) - low) * 0.15
      lower += (low - lower) * 0.15
      4 * lower * Math.exp(-t * 60)
    end
  end

  # A spring: a note that wobbles up and down, less and less.
  def boing(seconds)
    phase = 0.0
    sound(seconds) do |t|
      phase += (230 + 60 * t + 70 * Math.sin(TAU * 11 * t) * Math.exp(-t * 5)) / RATE
      Math.sin(TAU * phase) * Math.exp(-t * 4)
    end
  end

  # Lays sounds over each other, each starting a moment in.
  def mix(*parts)
    length = parts.map { |start, samples| (start * RATE).round + samples.size }.max
    out = Array.new(length, 0.0)
    parts.each do |start, samples|
      offset = (start * RATE).round
      samples.each_with_index { |sample, i| out[offset + i] += sample }
    end
    out
  end

  # A WAV file is a 44-byte header, then every sample as a 16-bit number.
  def write(name, samples, volume)
    data = samples.map { |sample| (sample * volume * 32_767).round }.pack("s<*")
    header = ["RIFF", 36 + data.bytesize, "WAVE", "fmt ", 16, 1, 1, RATE, RATE * 2, 2, 16, "data", data.bytesize]
    path = File.join(@dir, "#{name}.wav")
    File.binwrite(path, header.pack("a4Va4a4VvvVVvva4V") + data)
    path
  end
end

# A shape on the table. `home` is its place there; x and y are where it is now,
# `lift` how far it floats above its shadow (and `hop` a little more, when a key
# makes it jump), and `state` what it is doing: :arriving, :table, :held,
# :flying, :sorted or :going_home.
Piece = Struct.new(:kind, :team, :color, :home, :x, :y, :size, :angle, :lift, :hop, :state, :slot, :look, :wiggle, :dragged)
# A hole in the lid, in window coordinates.
Hole = Struct.new(:kind, :team, :x, :y, :size)
# A scrap of confetti.
Scrap = Struct.new(:art, :x, :y, :vx, :vy, :width, :spin, :age, :life)

Shoes.app(title: "Shape Sorter", width: W, height: H, resizable: false) do
  # ---------------------------------------------------------------- little helpers

  def tint(color, amount)
    color.map { |c| (c + (255 - c) * amount).round }
  end

  def shade(color, amount)
    color.map { |c| (c * (1 - amount)).round }
  end

  def between(a, b, k)
    a + (b - a) * k
  end

  # Eases: `smooth` starts and ends gently, `springy` overshoots and settles like a spring.
  def smooth(k)
    k * k * (3 - 2 * k)
  end

  def springy(k)
    c = 2.2
    1 + (c + 1) * (k - 1)**3 + c * (k - 1)**2
  end

  def sound(name)
    @music.play(name, @clock)
  end

  # A little animation: calls the block every frame for `seconds`, with how far
  # along it is (0 to 1), starting `after` seconds from now.
  def tween(seconds, after: 0, &step)
    @tweens << { age: -after, seconds: seconds, step: step }
  end

  # Runs the block once, `seconds` from now.
  def later(seconds, &block)
    tween(0.001, after: seconds) { |k| block.call if k >= 1 }
  end

  def run_tweens(dt)
    @tweens.dup.each do |tween|
      tween[:age] += dt
      next if tween[:age] < 0

      k = [tween[:age] / tween[:seconds], 1.0].min
      tween[:step].call(k)
      @tweens.delete(tween) if k >= 1
    end
  end

  # ---------------------------------------------------------------- drawing shapes

  # Draws the outline of a shape `size` across, centred on (x, y) and turned by `angle` radians.
  def outline_of(kind, x, y, size, angle = 0.0)
    r = size / 2.0
    cos, sin = Math.cos(angle), Math.sin(angle)
    turn = ->(px, py) { [x + r * (px * cos - py * sin), y + r * (px * sin + py * cos)] }
    case kind
    when :circle
      oval x, y, size * 0.98, center: true
    when :heart
      shape do
        HEART.each { |command, *xy| send(command, *xy.each_slice(2).flat_map { |px, py| turn.(px, py) }) }
      end
    else
      rounded(CORNERS[kind].map { |px, py| turn.(px, py) }, ROUNDING[kind])
    end
  end

  # A closed shape through `points` with its corners rounded off. `round` says how far
  # along each edge the rounding starts (a list, taken in turn for the corners).
  def rounded(points, round)
    cuts = points.each_with_index.map do |(x, y), i|
      k = round[i % round.size]
      before, after = points[i - 1], points[(i + 1) % points.size]
      [[x + (before[0] - x) * k, y + (before[1] - y) * k], [x, y], [x + (after[0] - x) * k, y + (after[1] - y) * k]]
    end
    shape do
      move_to(*cuts[0][0])
      cuts.each_with_index do |(into, corner, out), i|
        line_to(*into) unless i.zero?
        curve_to(*corner, *corner, *out)
      end
      line_to(*cuts[0][0])
    end
  end

  # The mark every big kid colour carries: three dots, or a ring.
  def team_mark(team, x, y, size, color)
    s = size * 0.1
    if TEAMS[team][:mark] == :dots
      nostroke
      fill color
      [[-1.05, 0.62], [1.05, 0.62], [0, -0.95]].each { |dx, dy| oval x + dx * s, y + dy * s, s * 1.15, center: true }
    else
      nofill
      stroke color
      strokewidth [size * 0.06, 2].max
      oval x, y, s * 2.7, center: true
    end
  end

  # One shape as it looks on the table: a shadow, a glossy body and a shine.
  # `lift` raises it above its shadow.
  def piece_art(piece, x, y, size, angle, lift)
    return if size < 2

    color = piece.color
    nostroke
    fill rgb(80, 40, 10, [0.2 - lift * 0.004, 0.07].max)
    oval x, y + size * 0.46, size * (0.82 + lift * 0.005), size * 0.2, center: true
    y -= lift
    stroke rgb(*shade(color, 0.3))
    strokewidth [size * 0.035, 1.5].max
    fill rgb(*tint(color, 0.38))..rgb(*color)
    outline_of(piece.kind, x, y, size, angle)
    nostroke
    fill rgb(255, 255, 255, 0.5)
    shine = [-0.34, -0.4]
    oval x + size / 2 * (shine[0] * Math.cos(angle) - shine[1] * Math.sin(angle)),
      y + size / 2 * (shine[0] * Math.sin(angle) + shine[1] * Math.cos(angle)), size * 0.2, size * 0.11, center: true
    team_mark(piece.team, x, y + size * 0.05, size, rgb(255, 255, 255, 0.92)) if piece.team
  end

  # A hole in the lid: a pale lip of wood, the dark inside, and in big kid mode a
  # rim of its colour with its mark.
  def hole_art(kind, team, x, y, size)
    nostroke
    fill rgb(255, 246, 222)
    outline_of(kind, x, y + 3, size + 12)
    fill "#6b4428"
    outline_of(kind, x, y, size)
    fill "#2f1c10"
    outline_of(kind, x, y + size * 0.08, size * 0.84)
    return unless team

    color = TEAMS[team][:color]
    nofill
    stroke rgb(*color)
    strokewidth 5
    outline_of(kind, x, y, size + 7)
    team_mark(team, x, y + size * 0.06, size * 0.9, rgb(*tint(color, 0.15)))
  end

  # ---------------------------------------------------------------- the box and its face

  # Where the holes go: five in a row, or ten in two rows for big kids.
  def make_holes
    if @big_kid
      TEAMS.keys.each_with_index.flat_map do |team, row|
        KINDS.each_with_index.map { |kind, i| Hole.new(kind, team, BOX_X + 80 + i * 100, BOX_Y + 82 + row * 88, 66) }
      end
    else
      KINDS.each_with_index.map { |kind, i| Hole.new(kind, nil, BOX_X + 80 + i * 100, BOX_Y + 124, 80) }
    end
  end

  def draw_holes
    @holes = make_holes
    @lid_holes.clear do
      @holes.each { |hole| hole_art(hole.kind, hole.team, hole.x - BOX_X, hole.y - BOX_Y, hole.size) }
      nofill
      stroke white
      strokewidth 5
      @glow = oval 0, 0, 10, center: true, hidden: true
    end
  end

  # The box is drawn in its own slot, 560 by 360, with its top left at (BOX_X, BOX_Y).
  def build_box
    @box = stack(left: BOX_X, top: BOX_Y, width: 560, height: 360) do
      # the front, with its face
      stroke "#b8692c"
      strokewidth 3
      fill "#f2ac66".."#d7813f"
      rect 26, 190, 508, 146, curve: 24
      nostroke
      fill rgb(255, 255, 255, 0.14)
      rect 40, 234, 480, 6, curve: 3
      # the lid, with the grain of the wood
      stroke "#c98b4e"
      strokewidth 3
      fill "#ffe8bd".."#f6c98a"
      rect 20, 26, 520, 190, curve: 30
      nofill
      stroke rgb(190, 130, 70, 0.22)
      strokewidth 2
      [[50, 60, 490, 52], [60, 200, 480, 206], [70, 118, 180, 112]].each do |x1, y1, x2, y2|
        shape do
          move_to x1, y1
          curve_to (x1 + x2) / 2.0, y1 - 8, (x1 + x2) / 2.0, y2 + 8, x2, y2
        end
      end
      @lid_holes = stack(left: 0, top: 0, width: 560, height: 360) {}
      build_face
    end
  end

  def build_face
    eyes = [220, 340]
    nostroke
    fill rgb(255, 120, 130, 0.4)
    [170, 390].each { |x| oval x, 290, 44, 22, center: true }
    @whites = eyes.map { |x| oval x, 262, 46, 52, center: true, fill: white, stroke: rgb(120, 60, 30, 0.5), strokewidth: 2 }
    nostroke
    @pupils = eyes.map { |x| oval x, 266, 24, 27, center: true, fill: INK }
    @glints = eyes.map { |x| oval x + 5, 259, 8, center: true, fill: white }
    nofill
    stroke INK
    strokewidth 5
    cap :curve
    @happy_eyes = eyes.map do |x|
      shape do
        move_to x - 16, 268
        curve_to x - 10, 250, x + 10, 250, x + 16, 268
      end
    end
    @smile = shape do
      move_to 256, 298
      curve_to 270, 314, 290, 314, 304, 298
    end
    nostroke
    fill "#8a3b32"
    @grin = shape do
      move_to 244, 294
      curve_to 256, 334, 304, 334, 316, 294
      line_to 244, 294
    end
    fill "#ff8f9e"
    @tongue = oval 280, 318, 26, 12, center: true
    fill "#8a3b32"
    @oh = oval 280, 306, 22, 26, center: true
    express(:smile)
  end

  # The face shows :smile, :happy (eyes shut with joy, mouth wide open) or :oh.
  def express(face, seconds = nil)
    @face = face
    @face_until = seconds && @clock + seconds
    happy = face == :happy
    (@whites + @pupils + @glints).each { |part| part.hidden = happy }
    @happy_eyes.each { |part| part.hidden = !happy }
    @smile.hidden = face != :smile
    @grin.hidden = !happy
    @tongue.hidden = !happy
    @oh.hidden = face != :oh
  end

  # The eyes follow what matters most: the shape in hand, or else the pointer.
  def look(dt)
    express(:smile) if @face_until && @clock > @face_until
    target = @held ? [@held.x, @held.y - @held.lift] : @pointer
    @blink -= dt
    closed = @blink < 0.13
    @blink = 2.5 + @luck.rand * 3 if @blink < 0
    [220, 340].each_with_index do |ex, i|
      dx, dy = 0, 0
      if target
        away_x = target[0] - (BOX_X + ex)
        away_y = target[1] - (BOX_Y + 262)
        far = [Math.hypot(away_x, away_y), 1].max
        dx, dy = (away_x / far * 9).round, (away_y / far * 9).round
      end
      now = [dx, dy, closed, @face]
      next if @eyes_were[i] == now

      @eyes_were[i] = now
      @pupils[i].style(left: ex + dx, top: 266 + dy, height: closed ? 3 : 27)
      @glints[i].style(left: ex + 5 + dx, top: 259 + dy, hidden: closed || @face == :happy)
      @whites[i].style(height: closed ? 6 : 52)
    end
  end

  # The box hops with joy, and its shadow shrinks while it is in the air.
  def hop_box(height = 16, times = 1)
    tween(0.42 * times) do |k|
      up = height * Math.sin(Math::PI * (k * times % 1)).abs
      up = 0 if k >= 1
      @box.move(BOX_X, (BOX_Y - up).round)
      @box_shadow.style(width: (540 - up * 4).round, left: 500)
    end
  end

  def giggle
    express(:happy, 0.8)
    hop_box(10)
    sound "giggle"
  end

  # ---------------------------------------------------------------- the shapes

  # Round 1 has the circle, the square and the triangle; each round adds one
  # more, and after the heart they start to repeat. Big kids get more at once.
  def round_pieces(round)
    if @big_kid
      count = [2 + round * 2, 8].min
      @holes.shuffle(random: @luck).first(count).map { |hole| [hole.kind, hole.team] }
    else
      count = [round + 2, 7].min
      kinds = KINDS.first([count, 5].min)
      kinds += Array.new(count - kinds.size) { KINDS.sample(random: @luck) }
      kinds.shuffle(random: @luck).map { |kind| [kind, nil] }
    end
  end

  # Places along the table, in one row, or two staggered rows when there are many.
  def table_spots(count)
    span = [(count - 1) * 150, 680].min
    Array.new(count) do |i|
      x = 500 - span / 2.0 + (count == 1 ? 0 : i * span / (count - 1).to_f)
      y = count > 5 ? (i.even? ? 530 : 614) : 570
      [x, y]
    end
  end

  def start_round
    @round += 1
    @badge.replace @round.to_s
    tween(0.5) do |k|
      size = (56 * (0.8 + 0.2 * springy(k))).round(1)
      @badge_disc.style(width: size, height: size)
    end
    @pieces.each { |piece| piece.slot.remove }
    @held = nil
    wanted = round_pieces(@round)
    @pieces = wanted.zip(table_spots(wanted.size)).each_with_index.map do |((kind, team), home), i|
      color = team ? TEAMS[team][:color] : PLAIN[(i * 2 + @round) % PLAIN.size]
      slot = nil
      @piece_layer.append { slot = stack(left: 0, top: 0, width: 140, height: 140, cursor: :hand_cursor) {} }
      piece = Piece.new(kind, team, color, home, home[0], home[1], 0.0, 0.0, 0.0, 0.0, :arriving, slot, nil, 0.0, false)
      tween(0.45, after: 0.3 + i * 0.16) do |k|
        sound "pop#{i}" if piece.size.zero?
        piece.size = PIECE * springy(k)
        piece.state = :table if k >= 1
      end
      piece
    end
    draw_progress
  end

  # Moves a shape's slot to where it is, and draws it again only if it looks different.
  def show(piece)
    piece.slot.move((piece.x - 70).round, (piece.y - 70).round)
    look = [piece.size.round(1), piece.angle.round(3), (piece.lift + piece.hop).round(1)]
    return if look == piece.look

    piece.look = look
    piece.slot.clear { piece_art(piece, 70, 70, piece.size, piece.angle, piece.lift + piece.hop) }
  end

  # Shapes sitting on the table wobble now and then, and the one under the pointer
  # wobbles for as long as the pointer is there.
  def wobble(dt)
    @pieces.each do |piece|
      piece.wiggle = [piece.wiggle - dt, 0].max
      if piece.state == :table || piece.state == :held
        hovered = piece == @hovered_piece && piece.state == :table
        swing = piece.wiggle > 0 ? piece.wiggle : (hovered ? 0.5 : 0)
        piece.angle = swing > 0 ? Math.sin(@clock * 16 + piece.home[0]) * 0.16 * [swing, 1].min : 0.0
        want = piece.state == :held ? 22 : 0
        piece.lift += (want - piece.lift) * [dt * 12, 1].min
      end
      show(piece) unless piece.state == :sorted
    end
    return unless @clock > @next_wobble

    @next_wobble = @clock + 2.2 + @luck.rand * 2
    idle = @pieces.select { |piece| piece.state == :table }
    idle.sample(random: @luck).wiggle = 0.9 if idle.any?
  end

  def piece_at(x, y)
    @pieces.select { |piece| %i[table held].include?(piece.state) }
      .map { |piece| [piece, Math.hypot(piece.x - x, piece.y - piece.lift - y)] }
      .select { |_, distance| distance < PIECE * 0.62 }
      .min_by { |_, distance| distance }&.first
  end

  def hole_at(x, y)
    @holes.find { |hole| Math.hypot(hole.x - x, hole.y - y) < hole.size * 0.62 }
  end

  def on_box?(x, y)
    x.between?(BOX_X + 20, BOX_X + 540) && y.between?(BOX_Y + 26, BOX_Y + 336)
  end

  # Picks a shape up. Clicking it again, or the table, puts it down.
  def grab(piece, x, y)
    let_go_of(@held) if @held && @held != piece
    if @held == piece
      let_go_of(piece)
      @drag = nil
      return
    end
    @held = piece
    piece.state = :held
    piece.wiggle = 0.4
    @held_since = @clock
    @drag = { from: [x, y], offset: [piece.x - x, piece.y - y] }
    sound "pick"
  end

  def let_go_of(piece)
    return unless piece

    @held = nil if @held == piece
    go_home(piece) if piece.state == :held
  end

  # Carries the shape in hand with the pointer, once the pointer has really moved.
  def carry(x, y)
    return unless @drag && @held

    @held.dragged ||= Math.hypot(x - @drag[:from][0], y - @drag[:from][1]) > 10
    return unless @held.dragged

    @held.x = (x + @drag[:offset][0]).clamp(70, W - 70)
    @held.y = (y + @drag[:offset][1] + @held.lift).clamp(90, H - 60)
  end

  # Letting go after a drag drops the shape into the hole under it, or sends it home.
  def put_down(x, y)
    return unless @drag && @held

    piece = @held
    @drag = nil
    return unless piece.dragged

    piece.dragged = false
    hole = hole_at(piece.x, piece.y - piece.lift) || hole_at(x, y)
    hole ? drop(piece, hole) : let_go_of(piece)
  end

  def go_home(piece)
    piece.state = :going_home
    from = [piece.x, piece.y]
    from_size, from_lift = piece.size, piece.lift
    tween(0.5) do |k|
      e = springy(k)
      piece.x = between(from[0], piece.home[0], e)
      piece.y = between(from[1], piece.home[1], e)
      piece.size = between(from_size, PIECE, smooth(k))
      piece.lift = between(from_lift, 0, smooth(k))
      piece.state = :table if k >= 1
    end
  end

  # The shape flies to the hole in an arc. If it fits, in it goes; if not, it
  # bumps the lid and boings home.
  def drop(piece, hole)
    @held = nil if @held == piece
    @drag = nil
    piece.state = :flying
    @glow.hide
    fits = piece.kind == hole.kind && piece.team == hole.team
    from = [piece.x, piece.y - piece.lift]
    from_size = piece.size
    piece.lift = 0
    tween(0.42) do |k|
      e = smooth(k)
      piece.x = between(from[0], hole.x, e)
      piece.y = between(from[1], hole.y, e) - Math.sin(Math::PI * k) * 70
      piece.size = between(from_size, hole.size * 0.92, e)
      next if k < 1

      fits ? sink(piece, hole) : boing(piece)
    end
  end

  def sink(piece, hole)
    sound "clunk"
    tween(0.22) do |k|
      piece.size = hole.size * 0.92 * (1 - k)
      piece.y = hole.y + 10 * k
      next if k < 1

      piece.state = :sorted
      piece.slot.clear
      cheer(hole)
    end
  end

  def boing(piece)
    sound "boing"
    express(:oh, 0.9)
    piece.wiggle = 0.6
    tween(0.25) do |k|
      piece.y -= 3 * Math.cos(Math::PI * k)
      go_home(piece) if k >= 1
    end
  end

  def cheer(hole)
    sound "cheer"
    express(:happy, 1.1)
    hop_box
    burst(hole.x, hole.y, 16, 0.5)
    draw_progress
    return unless @pieces.all? { |piece| piece.state == :sorted }

    round = @round
    later(0.6) { celebrate_round if @round == round }
  end

  # All sorted: a shower of confetti, a fanfare, a star for the round, and then more shapes.
  def celebrate_round
    sound "hooray"
    express(:happy, 2.2)
    hop_box(20, 3)
    shower(90)
    fly_star
    round = @round
    later(2.8) { start_round if @round == round }
  end

  # A star with a face bounces up over the box, then flies to the row of stars
  # at the top, one for every round done.
  def fly_star
    goal = [112 + [@stars_earned, 8].min * 30, 42]
    @star_flying = true
    @prize.show
    tween(2.0) do |k|
      if k < 0.55
        x, y, size = 500, 200, 150 * springy([k / 0.35, 1].min)
      else
        e = smooth((k - 0.55) / 0.45)
        x, y, size = between(500, goal[0], e), between(200, goal[1], e) - Math.sin(Math::PI * e) * 60, between(150, 26, e)
      end
      @prize.clear { star_friend(x, y, size) }
      next if k < 1

      land_star
    end
  end

  def land_star
    @star_flying = false
    @prize.clear
    @prize.hide
    @stars_earned += 1
    draw_stars
  end

  # A star with a smiling face.
  def star_friend(x, y, size)
    return if size < 2

    stroke "#e0922a"
    strokewidth [size * 0.03, 1.5].max
    fill "#fff08a".."#ffbb2e"
    rounded(CORNERS[:star].map { |px, py| [x + px * size / 2, y + py * size / 2] }, ROUNDING[:star])
    return if size < 40

    nostroke
    fill rgb(255, 120, 130, 0.45)
    oval x - size * 0.2, y + size * 0.1, size * 0.12, size * 0.07, center: true
    oval x + size * 0.2, y + size * 0.1, size * 0.12, size * 0.07, center: true
    fill INK
    oval x - size * 0.1, y - size * 0.01, size * 0.07, size * 0.085, center: true
    oval x + size * 0.1, y - size * 0.01, size * 0.07, size * 0.085, center: true
    nofill
    stroke INK
    strokewidth size * 0.03
    cap :curve
    shape do
      move_to x - size * 0.08, y + size * 0.08
      curve_to x - size * 0.04, y + size * 0.14, x + size * 0.04, y + size * 0.14, x + size * 0.08, y + size * 0.08
    end
  end

  # Clicking a hole with nothing in hand makes the shapes that fit it wiggle.
  def show_fits(hole)
    sound "ooh"
    fits = @pieces.select { |piece| piece.state == :table && piece.kind == hole.kind && piece.team == hole.team }
    fits.each { |piece| piece.wiggle = 1.4 }
    express(:oh, 0.6) if fits.empty?
  end

  # A soft glow around the hole the shape in hand belongs in: after a while
  # for the little ones, or at once with the space bar.
  def hint(dt)
    target = @held && @holes.find { |hole| hole.kind == @held.kind && hole.team == @held.team }
    waited = @held && (@hint_asked || (!@big_kid && @clock - @held_since > 5))
    unless target && waited
      @glow.hide
      return
    end
    pulse = (Math.sin(@clock * Math::PI * 2 * 0.8) + 1) / 2
    @glow.style(left: target.x - BOX_X, top: target.y - BOX_Y, width: target.size + 24, height: target.size + 24,
      stroke: rgb(255, 255, 255, 0.35 + 0.5 * pulse), hidden: false)
  end

  # ---------------------------------------------------------------- the top of the window

  def draw_progress
    @progress.clear do
      count = @pieces.size
      @pieces.each_with_index do |piece, i|
        x = 500 + (i - (count - 1) / 2.0) * 34
        if piece.state == :sorted
          nostroke
          fill "#ffb84d".."#ff8a3d"
          oval x, 40, 24, center: true
          fill white
          oval x, 40, 8, center: true
        else
          nofill
          stroke rgb(160, 110, 70, 0.6)
          strokewidth 3
          oval x, 40, 18, center: true
        end
      end
    end
  end

  def draw_stars
    @stars.clear do
      shown = [@stars_earned, 9].min
      shown.times do |i|
        nostroke
        fill "#ffe066".."#ffb52e"
        stroke "#e0922a"
        strokewidth 1.5
        rounded(CORNERS[:star].map { |px, py| [112 + i * 30 + px * 12, 42 + py * 12] }, ROUNDING[:star])
      end
    end
  end

  # The speaker, with sound waves when it is on and a little cross when it is off.
  def speaker(x, y)
    nostroke
    fill INK
    rect x - 14, y - 6, 8, 12, curve: 2
    shape do
      move_to x - 7, y - 6
      line_to x + 3, y - 14
      line_to x + 3, y + 14
      line_to x - 7, y + 6
    end
    nofill
    stroke INK
    strokewidth 3
    cap :curve
    waves = [9, 17].map { |d| arc x + 2, y, d * 2, d * 2, -Math::PI / 3.2, Math::PI / 3.2, center: true }
    cross = [line(x + 9, y - 6, x + 19, y + 6), line(x + 9, y + 6, x + 19, y - 6)]
    cross.each(&:hide)
    [waves, cross]
  end

  def toggle_sound
    @music.muted = !@music.muted
    @waves.each { |wave| wave.hidden = @music.muted }
    @cross.each { |line| line.hidden = !@music.muted }
    sound "hello"
  end

  def toggle_big_kid
    @big_kid = !@big_kid
    @knob.move(@big_kid ? 876 : 848, 44)
    @knob_check.hidden = !@big_kid
    @switch_track.fill = @big_kid ? "#8fd18a" : "#e6d8c8"
    draw_holes
    @tweens.clear
    land_star if @star_flying
    @box.move(BOX_X, BOX_Y)
    @box_shadow.style(width: 540)
    @round = 0
    start_round
    sound "switch"
  end

  def top_button(x, y)
    return :sound if Math.hypot(x - 952, y - 44) < 36
    return :big_kid if x.between?(740, 912) && y.between?(10, 78)
  end

  # ---------------------------------------------------------------- confetti

  def burst(x, y, count, speed)
    count.times do
      angle = -Math::PI / 2 + @luck.rand(-1.1..1.1)
      fling = @luck.rand(260..460) * speed
      confetti(x, y, Math.cos(angle) * fling, Math.sin(angle) * fling, 1.4)
    end
  end

  def shower(count)
    count.times { confetti(@luck.rand(40..960), @luck.rand(-160..-10), @luck.rand(-40..40), @luck.rand(40..160), 3.0) }
  end

  def confetti(x, y, vx, vy, life)
    color = PLAIN.sample(random: @luck)
    art = nil
    @confetti_layer.append { art = rect x, y, 12, 16, curve: 3, fill: rgb(*color), stroke: rgb(0, 0, 0, 0) }
    @scraps << Scrap.new(art, x, y, vx, vy, 12.0, @luck.rand(5.0..11.0), 0.0, life)
  end

  # Confetti falls and flutters: turning over is its width going thin and wide again.
  def fall(dt)
    @scraps.reject! do |scrap|
      scrap.age += dt
      scrap.vy += 420 * dt
      scrap.vx *= 0.985
      scrap.x += scrap.vx * dt
      scrap.y += scrap.vy * dt
      if scrap.age > scrap.life || scrap.y > H + 20
        scrap.art.remove
        next true
      end
      flat = (Math.cos(scrap.age * scrap.spin) * scrap.width).abs.round(1) + 1
      scrap.art.style(left: (scrap.x - flat / 2).round(1), top: scrap.y.round(1), width: flat)
      false
    end
  end

  # ---------------------------------------------------------------- the keyboard

  def press(key)
    return hold_escape if key.to_s == "escape"
    return if @clock - @last_key < 0.07

    @last_key = @clock
    if key == " " && @held
      @hint_asked = true
      sound "hint"
      return
    end
    resting = @pieces.select { |piece| piece.state == :table }
    return giggle if resting.empty?

    piece = resting.sample(random: @luck)
    piece.wiggle = 0.5
    tween(0.34) { |k| piece.hop = 26 * Math.sin(Math::PI * k) }
    sound "hop#{@luck.rand(3..11)}"
  end

  # Holding Esc down sends it again and again. Two seconds of that closes the
  # app; a tap, or a small hand mashing it now and then, does not.
  def hold_escape
    if @escape_since && @clock - @escape_last <= escape_patience
      @escape_repeats += 1
    else
      @escape_since = @clock
      @escape_repeats = 0
    end
    @escape_last = @clock
  end

  # The Mac waits a moment before a held key starts repeating, then repeats it quickly.
  def escape_patience
    @escape_repeats.zero? ? 1.1 : 0.3
  end

  def watch_escape
    return unless @escape_since

    held = @clock - @escape_since
    if @clock - @escape_last > escape_patience
      @escape_since = nil
      @escape_repeats = 0
      @hold_ring.hide
      return
    end
    @hold_ring.style(angle2: -Math::PI / 2 + 2 * Math::PI * [held / 2.0, 1].min, hidden: false)
    close if held >= 2.0
  end

  # ---------------------------------------------------------------- setting up

  @music = Music.new
  @luck = Random.new(11)
  @clock = 0.0
  @tweens = []
  @pieces = []
  @scraps = []
  @round = 0
  @stars_earned = 0
  @big_kid = false
  @blink = 2.0
  @eyes_were = [nil, nil]
  @next_wobble = 1.5
  @last_key = -1.0
  @escape_last = -9.0
  @escape_repeats = 0
  # Fredoka beside the app, in fonts/ or _fonts/ (where a packaged app carries it), or in the
  # Kids folder's shared _fonts, as the other Kids apps look.
  font_file = [["Fredoka.ttf"], ["fonts", "Fredoka.ttf"], ["_fonts", "Fredoka.ttf"], ["..", "_fonts", "Fredoka.ttf"]]
    .map { |parts| File.join(__dir__, *parts) }.find { |file| File.exist?(file) }
  rounded_font = font_file && font(font_file) ? "Fredoka" : "Avenir Next, Helvetica Neue, sans-serif"

  # the playroom: a soft wall, a few bubbles of light, and the table
  background "#eaf6ff".."#fff1e2"
  nostroke
  [[90, 150, 120], [930, 200, 150], [160, 330, 70], [860, 360, 90], [60, 260, 40]].each do |x, y, d|
    oval x, y, d, center: true, fill: rgb(255, 255, 255, 0.45)
  end
  rect 0, TABLE_TOP, W, H - TABLE_TOP, fill: "#f3c58c".."#e0a060"
  rect 0, TABLE_TOP, W, 10, fill: rgb(255, 255, 255, 0.35)
  nofill
  stroke rgb(170, 100, 40, 0.18)
  strokewidth 2
  [[TABLE_TOP + 60, 0], [TABLE_TOP + 130, 40], [TABLE_TOP + 205, -30]].each do |y, bend|
    shape do
      move_to 0, y
      curve_to 330, y + bend, 660, y - bend, 1000, y
    end
  end
  nostroke
  rect 0, H - 30, W, 30, fill: "#d38f50"
  @box_shadow = oval 500, BOX_Y + 344, 540, 44, center: true, fill: rgb(110, 60, 20, 0.22)

  build_box
  draw_holes
  @piece_layer = stack(left: 0, top: 0, width: W, height: H) {}
  @confetti_layer = stack(left: 0, top: 0, width: W, height: H) {}
  @prize = stack(left: 0, top: 0, width: W, height: H, hidden: true) {}

  # the top of the window: the round, the stars won so far, and how many are in
  nostroke
  @badge_disc = oval 44, 42, 56, center: true, fill: "#ffffff".."#ffe9cf", stroke: "#e8b27a", strokewidth: 3
  stack left: 12, top: 23, width: 64 do
    @badge = para "1", align: "center", size: 28, family: rounded_font, weight: "bold", stroke: "#c0692e", margin: 0
  end
  @stars = stack(left: 0, top: 0, width: 400, height: 86) {}
  @progress = stack(left: 0, top: 0, width: W, height: 86) {}

  # the big kid switch and the sound switch
  nostroke
  rect 744, 16, 168, 56, curve: 28, fill: "#ffffff", stroke: "#e8cfb4", strokewidth: 2
  stack left: 762, top: 33, width: 70 do
    para "Big kid", size: 16, family: rounded_font, weight: "bold", stroke: "#8a5a36", margin: 0
  end
  @switch_track = rect 834, 30, 56, 28, curve: 14, fill: "#e6d8c8"
  @knob = oval 848, 44, 26, center: true, fill: white, stroke: "#c9b39c", strokewidth: 2
  nofill
  stroke "#3f8a3a"
  strokewidth 3
  cap :curve
  @knob_check = shape do
    move_to 870, 44
    line_to 875, 49
    line_to 883, 38
  end
  @knob_check.hide
  oval 952, 44, 60, center: true, fill: "#ffffff", stroke: "#e8cfb4", strokewidth: 2
  @waves, @cross = speaker(950, 44)

  # for grown-ups, on the front of the table
  stack left: 560, top: H - 24, width: 400 do
    para "Grown-ups: hold Esc for two seconds to close.", align: "right", size: 11, stroke: "#fff4e6", margin: 0
  end
  nofill
  strokewidth 3
  stroke "#fff4e6"
  @hold_ring = arc 986, H - 15, 14, 14, -Math::PI / 2, -Math::PI / 2, center: true, hidden: true

  # ---------------------------------------------------------------- hands on

  click do |_button, x, y|
    if (button = top_button(x, y))
      button == :sound ? toggle_sound : toggle_big_kid
    elsif (piece = piece_at(x, y))
      grab(piece, x, y)
    elsif (hole = hole_at(x, y))
      @held ? drop(@held, hole) : show_fits(hole)
    elsif on_box?(x, y)
      giggle
    elsif @held
      let_go_of(@held)
    else
      sound "tap"
      burst(x, y, 5, 0.3)
    end
  end

  motion do |x, y|
    @pointer = [x, y]
    @hovered_piece = piece_at(x, y)
    carry(x, y)
  end

  release { |_button, x, y| put_down(x, y) }

  keypress { |key| press(key) }

  animate(FPS) do |frame|
    dt = 1.0 / FPS
    @clock = frame * dt
    @hint_asked = false unless @held
    run_tweens(dt)
    wobble(dt)
    hint(dt)
    look(dt)
    fall(dt)
    watch_escape
  end

  start_round
end
