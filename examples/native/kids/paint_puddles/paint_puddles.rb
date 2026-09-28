# Paint Puddles: finger painting for little hands.
#
# Press anywhere on the paper and draw. The fat brush runs through the rainbow
# as it goes, and every stroke sings a soft note: high near the top of the
# page, low near the bottom. Hold still and the paint pools into a puddle of
# rainbow rings that drips when you let go. Pick the star, heart, sun or fish
# to stamp friends onto the page, and press the wave to wash it all away.
# Every key on the keyboard splats paint too, where that key sits on the
# keyboard, so mashing is welcome.
#
# For grown-ups: the speaker button turns the sound off and on. Hold Esc for
# two seconds to close the app. Cmd-Q works too (no app can switch off the
# Mac's own shortcuts). Nothing is saved and nothing goes on the network.
#
# The sounds are made right here in plain Ruby: each one is worked out as
# numbers, written once as a small WAV file, and played with afplay, the Mac's
# own sound player.

require "tmpdir"
require "fileutils"

W, H = 1000, 700
PAPER_LEFT, PAPER_TOP, PAPER_RIGHT, PAPER_BOTTOM = 144, 20, 980, 660
BRUSH = 40              # how wide the brush is
STEP = 10               # the brush lays paint every 10 pixels it moves
STAMP = 100             # how big a stamped friend is
MOST_PAINT = 4000       # past this many pieces of paint, the oldest (long since covered) go
FPS = 30
INK = "#3d3450"         # eyes, smiles and outlines
PAPER = "#fffdf8"
WALL = "#ffeede"

# The brush walks through these colours as it moves, blending from one to the next.
RAINBOW = [
  [255, 107, 107], [255, 159, 67], [254, 202, 87], [102, 204, 122],
  [72, 190, 255], [110, 130, 250], [186, 120, 250], [255, 118, 177],
]

# The tray down the left: the brush, four stamps, the wave and the sound switch.
TOOLS = %i[brush star heart sun fish]
TOOL_X = 72
TOOL_Y = { brush: 70, star: 160, heart: 250, sun: 340, fish: 430 }
TOOL_TINT = { brush: "#ffe3e3", star: "#fff1c4", heart: "#ffe1ee", sun: "#ffe8cf", fish: "#dff2ff" }
WAVE_Y, SOUND_Y = 542, 618

# Each key splats where it sits on the keyboard: the top row stamps friends,
# the three rows of letters splat paint. Left is low and right is high.
KEY_ROWS = ["1234567890", "qwertyuiop", "asdfghjkl;", "zxcvbnm,./"]

# The heart and the fish, drawn in a box 100 across centred on (0, 0).
HEART = [[:move_to, 0, 44], [:curve_to, -12, 33, -50, 10, -50, -14], [:curve_to, -50, -34, -36, -44, -24, -44],
  [:curve_to, -12, -44, -3, -36, 0, -26], [:curve_to, 3, -36, 12, -44, 24, -44],
  [:curve_to, 36, -44, 50, -34, 50, -14], [:curve_to, 50, 10, 12, 33, 0, 44]]
FISH_TAIL = [[:move_to, -28, 0], [:curve_to, -38, -10, -46, -24, -52, -26], [:curve_to, -46, -10, -46, 10, -52, 26],
  [:curve_to, -46, 24, -38, 10, -28, 0]]
FISH_FIN = [[:move_to, -6, -24], [:curve_to, 0, -38, 14, -40, 22, -30], [:line_to, 14, -22]]
FISH_BODY = [[:move_to, -36, 0], [:curve_to, -24, -32, 26, -36, 44, -6], [:curve_to, 47, -2, 47, 4, 44, 8],
  [:curve_to, 26, 34, -24, 32, -36, 0]]

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
    @dir = Dir.mktmpdir("paint-puddles")
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
    false # no afplay here (not a Mac): paint in silence
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
    when /\Anote(\d+)\z/ then bell(pitch($1.to_i), 0.9)
    when /\Asplat(\d+)\z/ then mix([0, pat(0.03)], [0.01, bell(pitch($1.to_i), 0.6)])
    when /\Aring(\d+)\z/ then glide(pitch($1.to_i) * 0.8, pitch($1.to_i), 0.5)
    when "star" then mix([0, bell(pitch(9), 0.5)], [0.09, bell(pitch(12), 0.8)])
    when "heart" then mix([0, glide(pitch(0) * 0.9, pitch(0), 0.3)], [0.16, glide(pitch(2) * 0.9, pitch(2), 0.5)])
    when "sun" then mix([0, hum(pitch(0), 1.1)], [0.04, hum(pitch(2), 1.05)], [0.08, hum(pitch(3), 1.0)], [0.2, bell(pitch(10), 0.8)])
    when "fish" then mix([0, glide(330, 520, 0.1)], [0.13, glide(390, 620, 0.12)], [0.28, glide(460, 700, 0.14)])
    when "drip" then glide(pitch(8), pitch(6), 0.18)
    when "pick" then glide(pitch(5), pitch(7), 0.12)
    when "hello" then mix([0, bell(pitch(5), 0.5)], [0.12, bell(pitch(9), 0.7)])
    when "wave" then mix([0, whoosh(2.0)], *[12, 10, 9, 7, 5, 4, 2, 0].each_with_index.map { |step, i| [0.3 + i * 0.1, bell(pitch(step), 0.7)] })
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
      wave * [t * 12, 1].min * Math.exp(-t * 2.5)
    end
  end

  # A sine that slides from one pitch to another: bloops, blubs and boops.
  def glide(from, to, seconds)
    phase = 0.0
    sound(seconds) do |t|
      phase += (from + (to - from) * [t / seconds * 2, 1].min) / RATE
      Math.sin(TAU * phase) * Math.exp(-t * 5)
    end
  end

  # The soft pat of paint landing: a breath of noise with the hiss taken out.
  def pat(seconds)
    noise = Random.new(3)
    low = 0.0
    sound(seconds) do |t|
      low += (noise.rand(-1.0..1.0) - low) * 0.2
      2 * low * Math.exp(-t * 80)
    end
  end

  # The sea: noise, smoothed until only its low rush is left, rising and falling once.
  def whoosh(seconds)
    noise = Random.new(5)
    low = lower = 0.0
    sound(seconds) do |t|
      low += (noise.rand(-1.0..1.0) - low) * 0.12
      lower += (low - lower) * 0.12
      5 * lower * Math.sin(Math::PI * t / seconds)**2
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

# Everything painted on the page is remembered as a Mark, with its left edge
# so the wave knows when to wash it away, and how many pieces it is made of.
Mark = Struct.new(:art, :left, :pieces, :gone)

Shoes.app(title: "Paint Puddles", width: W, height: H, resizable: false) do
  # ---------------------------------------------------------------- little helpers

  def mix(a, b, k)
    a.zip(b).map { |x, y| (x + (y - x) * k).round }
  end

  # Blends through the rainbow: 0 is the first colour, 1.5 is halfway from the second to the third.
  def rainbow(at)
    i = at.floor % RAINBOW.size
    mix(RAINBOW[i], RAINBOW[(i + 1) % RAINBOW.size], at % 1)
  end

  def halfway(a, b)
    [(a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0]
  end

  # Eases: `smooth` starts and ends gently, `springy` overshoots and settles like a spring.
  def smooth(k)
    k * k * (3 - 2 * k)
  end

  def springy(k)
    c = 2.4
    1 + (c + 1) * (k - 1)**3 + c * (k - 1)**2
  end

  def sound(name)
    @music.play(name, @clock)
  end

  # A little animation: calls the block every frame for `seconds`, with how far
  # along it is (0 to 1). If the paint it belongs to is washed away, it stops.
  def tween(seconds, mark = nil, &step)
    @tweens << { age: 0.0, seconds: seconds, mark: mark, step: step }
  end

  def run_tweens(dt)
    @tweens.reject! do |tween|
      next true if tween[:mark]&.gone

      tween[:age] += dt
      k = [tween[:age] / tween[:seconds], 1.0].min
      tween[:step].call(k)
      k >= 1
    end
  end

  # ---------------------------------------------------------------- the friends

  # Draws a friend centred on (x, y), `size` pixels across.
  def friend(kind, x, y, size)
    return if size < 2

    send("#{kind}_friend", x, y, size)
  end

  # A face: two shiny eyes, rosy cheeks and a smile.
  def face(x, y, size)
    eye = size * 0.1
    apart = size * 0.17
    nostroke
    fill rgb(255, 105, 135, 0.35)
    oval x - apart * 1.75, y + size * 0.1, size * 0.15, size * 0.09, center: true
    oval x + apart * 1.75, y + size * 0.1, size * 0.15, size * 0.09, center: true
    fill INK
    oval x - apart, y - size * 0.02, eye, eye * 1.25, center: true
    oval x + apart, y - size * 0.02, eye, eye * 1.25, center: true
    fill white
    oval x - apart + eye * 0.18, y - size * 0.02 - eye * 0.3, eye * 0.42, center: true
    oval x + apart + eye * 0.18, y - size * 0.02 - eye * 0.3, eye * 0.42, center: true
    smile(x, y + size * 0.1, size * 0.13, size * 0.09, [size * 0.045, 1.5].max)
  end

  def smile(x, y, half_width, depth, width)
    nofill
    stroke INK
    strokewidth width
    cap :curve
    shape do
      move_to x - half_width, y
      curve_to x - half_width * 0.5, y + depth, x + half_width * 0.5, y + depth, x + half_width, y
    end
  end

  # Draws a path of [:command, x, y, ...] steps, `k` times as big, moved to (x, y).
  def path(steps, x, y, k)
    shape do
      steps.each do |command, *xy|
        send(command, *xy.each_slice(2).flat_map { |px, py| [x + px * k, y + py * k] })
      end
    end
  end

  def outline(color, size)
    stroke color
    strokewidth [size * 0.035, 1.2].max
  end

  # A five-pointed star with softly rounded points.
  def star_friend(x, y, size)
    r = size * 0.5
    corners = Array.new(10) do |i|
      angle = -Math::PI / 2 + i * Math::PI / 5
      reach = i.even? ? r : r * 0.5
      [x + reach * Math.cos(angle), y + r * 0.06 + reach * Math.sin(angle)]
    end
    outline "#e59a1c", size
    fill "#ffe98a".."#ffc02e"
    shape do
      corners.each_with_index do |(cx, cy), i|
        round = i.even? ? 0.2 : 0.08
        before, after = corners[i - 1], corners[(i + 1) % 10]
        into = [cx + (before[0] - cx) * round, cy + (before[1] - cy) * round]
        out = [cx + (after[0] - cx) * round, cy + (after[1] - cy) * round]
        i.zero? ? move_to(*into) : line_to(*into)
        curve_to cx, cy, cx, cy, *out
      end
      line_to(*corners[0].zip(corners[9]).map { |a, b| a + (b - a) * 0.2 })
    end
    face(x, y + r * 0.12, size * 0.62)
  end

  def heart_friend(x, y, size)
    k = size / 100.0
    outline "#d9467e", size
    fill "#ff9cc2".."#ff5f95"
    path(HEART, x, y, k)
    nostroke
    fill rgb(255, 255, 255, 0.6)
    oval x - 28 * k, y - 26 * k, 15 * k, 9 * k, center: true
    face(x, y - 3 * k, size * 0.62)
  end

  def sun_friend(x, y, size)
    r = size * 0.29
    cap :curve
    stroke "#ffb13b"
    12.times do |i|
      angle = i * Math::PI / 6
      reach = i.even? ? 1.72 : 1.5
      strokewidth size * (i.even? ? 0.085 : 0.065)
      line x + Math.cos(angle) * r * 1.28, y + Math.sin(angle) * r * 1.28,
        x + Math.cos(angle) * r * reach, y + Math.sin(angle) * r * reach
    end
    outline "#eb9a2a", size
    fill "#fff08a".."#ffbe3b"
    oval x, y, r * 2, center: true
    face(x, y + r * 0.1, size * 0.6)
  end

  def fish_friend(x, y, size)
    k = size / 100.0
    outline "#2f7fd0", size
    fill "#9fe0ff".."#4f9ff7"
    path(FISH_TAIL, x, y, k)
    path(FISH_FIN, x, y, k)
    path(FISH_BODY, x, y, k)
    nostroke
    fill rgb(255, 255, 255, 0.45)
    oval x - 4 * k, y + 12 * k, 40 * k, 14 * k, center: true # its pale tummy
    nofill
    stroke rgb(255, 255, 255, 0.7)
    strokewidth [3.5 * k, 1].max
    cap :curve
    [-14, 0].each do |dx|
      shape do
        move_to x + dx * k, y - 12 * k
        curve_to x + (dx + 7) * k, y - 6 * k, x + (dx + 7) * k, y + 2 * k, x + dx * k, y + 8 * k
      end
    end
    nostroke
    fill white
    oval x + 22 * k, y - 6 * k, 20 * k, center: true
    fill INK
    oval x + 25 * k, y - 5 * k, 11 * k, 13 * k, center: true
    fill white
    oval x + 27 * k, y - 8 * k, 4.5 * k, center: true
    fill rgb(255, 105, 135, 0.4)
    oval x + 22 * k, y + 9 * k, 11 * k, 7 * k, center: true
    smile(x + 36 * k, y + 5 * k, 6 * k, 4 * k, [3.5 * k, 1.5].max)
  end

  # The brush on its button. Its bristles wear the colour it will paint next.
  def brush_icon(x, y, size)
    k = size / 100.0
    cap :curve
    stroke "#c48a55"
    strokewidth 13 * k
    line x - 32 * k, y + 32 * k, x + 2 * k, y - 2 * k
    stroke "#b9bfd0"
    strokewidth 17 * k
    line x + 2 * k, y - 2 * k, x + 11 * k, y - 11 * k
    stroke INK
    strokewidth 3 * k
    fill rgb(*rainbow(@hue))
    path([[:move_to, 8, -18], [:curve_to, 16, -34, 30, -44, 42, -42], [:curve_to, 44, -30, 34, -16, 18, -8],
      [:curve_to, 14, -10, 10, -14, 8, -18]], x, y, k)
  end

  def wave_icon(x, y, size)
    k = size / 100.0
    nostroke
    fill "#5aaef8".."#3b82e6"
    path([[:move_to, -40, 26], [:curve_to, -34, -8, -8, -34, 22, -24], [:curve_to, 6, -18, 0, -4, 12, 4],
      [:curve_to, 22, 10, 34, 6, 42, -2], [:line_to, 42, 26], [:line_to, -40, 26]], x, y, k)
    fill white
    [[22, -24, 12], [10, -26, 8], [34, -18, 7], [-2, 2, 6], [-18, 12, 5]].each do |dx, dy, d|
      oval x + dx * k, y + dy * k, d * k, center: true
    end
  end

  # The speaker, with sound waves when it is on and a little cross when it is off.
  def sound_icon(x, y, size)
    k = size / 100.0
    nostroke
    fill INK
    rect x - 30 * k, y - 11 * k, 16 * k, 22 * k, curve: 3 * k
    path([[:move_to, -16, -11], [:line_to, 4, -28], [:line_to, 4, 28], [:line_to, -16, 11]], x, y, k)
    nofill
    stroke INK
    strokewidth 6 * k
    cap :curve
    waves = [18, 34].map { |d| arc x + 2 * k, y, d * 2 * k, d * 2 * k, -Math::PI / 3.2, Math::PI / 3.2, center: true }
    cross = [line(x + 18 * k, y - 12 * k, x + 38 * k, y + 12 * k), line(x + 18 * k, y + 12 * k, x + 38 * k, y - 12 * k)]
    cross.each(&:hide)
    { waves: waves, cross: cross }
  end

  # ---------------------------------------------------------------- the paper

  def on_paper?(x, y)
    x.between?(PAPER_LEFT, PAPER_RIGHT) && y.between?(PAPER_TOP, PAPER_BOTTOM)
  end

  # Keeps a point far enough inside the paper that all the paint lands on it.
  def keep_on_paper(x, y, margin = BRUSH / 2 + 4)
    [x.clamp(PAPER_LEFT + margin, PAPER_RIGHT - margin), y.clamp(PAPER_TOP + margin, PAPER_BOTTOM - margin)]
  end

  # Remembers a new piece of paint, and lets the oldest go once there is a lot.
  def lay(art, left, pieces = 1)
    mark = Mark.new(art, left, pieces, false)
    @marks << mark
    @pieces += pieces
    forget(@marks.shift) while @pieces > MOST_PAINT
    mark
  end

  def forget(mark)
    mark.art.remove
    mark.gone = true
    @pieces -= mark.pieces
  end

  # Paints something made of several pieces (a stamp, a splat, a puddle, a drip)
  # in a slot of its own the size of the page, so it can be animated and washed
  # away in one go, and remembers it. `left` is where it starts, for the wave.
  def put_on_page(left, pieces, &drawing)
    art = nil
    @paint.append { art = stack(left: 0, top: 0, width: W, height: H, &drawing) }
    lay(art, left, pieces)
  end

  # ---------------------------------------------------------------- brush strokes

  def start_stroke(x, y)
    x, y = keep_on_paper(x, y)
    @stroke = { pen: [x, y], mid: [x, y], mouse: [x, y], still_at: [x, y], still: 0.0, length: 0.0,
                note_at: 0.0, sparkle_at: 0.0, puddle: nil }
    dab(x, y)
    sing(y)
  end

  # A round dab, so a tap on its own leaves a spot of paint.
  def dab(x, y)
    color = rainbow(@hue)
    dot = nil
    @paint.append { dot = oval(x, y, BRUSH, center: true, stroke: rgb(0, 0, 0, 0), fill: rgb(*color)) }
    lay(dot, x - BRUSH)
  end

  # Strokes stay smooth however the mouse moves: the pen trails the mouse by half
  # a step, and each piece of paint bends from one halfway point to the next.
  def extend_stroke(x, y)
    stroke_now = @stroke
    x, y = keep_on_paper(x, y)
    if Math.hypot(x - stroke_now[:still_at][0], y - stroke_now[:still_at][1]) > 5
      stroke_now[:still_at] = [x, y]
      stroke_now[:still] = 0.0
      settle_puddle
    end
    moved = Math.hypot(x - stroke_now[:mouse][0], y - stroke_now[:mouse][1])
    return if moved < STEP

    @hue += moved / 120.0
    stroke_now[:mouse] = [x, y]
    pen = halfway(stroke_now[:pen], [x, y])
    mid = halfway(stroke_now[:pen], pen)
    bend(stroke_now[:mid], stroke_now[:pen], mid, rainbow(@hue))
    stroke_now[:pen], stroke_now[:mid] = pen, mid
    stroke_now[:length] += moved
    if stroke_now[:length] - stroke_now[:note_at] > 90
      stroke_now[:note_at] = stroke_now[:length]
      sing(y)
    end
    if stroke_now[:length] - stroke_now[:sparkle_at] > 70
      stroke_now[:sparkle_at] = stroke_now[:length]
      sparkle(x + @luck.rand(-20..20), y + @luck.rand(-20..20), 12)
    end
    tint_brush
  end

  # A curve from `from` to `to` that leans towards `via`, the way a brush rounds a corner.
  def bend(from, via, to, color)
    pull = ->(point) { point.zip(via).map { |p, v| p + (v - p) * 2 / 3.0 } }
    piece = nil
    @paint.append do
      nofill
      cap :curve
      stroke rgb(*color)
      strokewidth BRUSH
      piece = shape do
        move_to(*from)
        curve_to(*pull.(from), *pull.(to), *to)
      end
    end
    lay(piece, [from[0], to[0]].min - BRUSH)
  end

  def end_stroke
    return unless @stroke

    stroke_now = @stroke
    @stroke = nil
    # the last little piece reaches the pointer, unless a puddle already covers it
    if stroke_now[:length] > 0 && !stroke_now[:puddle]
      bend(stroke_now[:mid], stroke_now[:pen], stroke_now[:mouse], rainbow(@hue))
    end
    if stroke_now[:puddle]
      settle_puddle(stroke_now)
    elsif stroke_now[:length] > 140 && @luck.rand < 0.5
      drip(*stroke_now[:mouse], rainbow(@hue), BRUSH * 0.4)
    end
  end

  # High on the page sings high, low sings low.
  def sing(y)
    step = ((PAPER_BOTTOM - y).fdiv(PAPER_BOTTOM - PAPER_TOP) * 12).round.clamp(0, 12)
    sound "note#{step}"
  end

  def tint_brush
    @brush_tip.fill = rgb(*rainbow(@hue))
  end

  # ---------------------------------------------------------------- puddles and drips

  # Holding the brush still pools the paint: ring after ring of the rainbow,
  # growing from the middle, each with a rising bloop.
  def pool(dt)
    stroke_now = @stroke
    return unless stroke_now && @tool == :brush

    stroke_now[:still] += dt
    return if stroke_now[:still] < 0.35

    puddle = stroke_now[:puddle]
    if puddle.nil? || puddle[:done]
      x, y = stroke_now[:still_at]
      # a puddle grows only as big as the paper around it allows (it is a little
      # wider than it is tall, like paint lying on a table)
      across = [x - PAPER_LEFT, PAPER_RIGHT - x].min - 6
      down = [y - PAPER_TOP, PAPER_BOTTOM - y].min - 6
      room = [across * 2 / 1.1, down * 2 / 0.92].min
      puddle = stroke_now[:puddle] = { x: x, y: y, rings: [], age: 0.0, done: false, room: room }
      puddle[:mark] = put_on_page(x - 95, 16) {}
    end
    return settle_puddle if puddle[:mark].gone # the wave took it

    puddle[:age] += dt
    if puddle[:rings].size < 7 && puddle[:age] >= puddle[:rings].size * 0.45
      @hue += 1.3
      tint_brush
      color = rainbow(@hue)
      ring = nil
      puddle[:mark].art.append do
        ring = oval(puddle[:x], puddle[:y], BRUSH * 0.8, center: true, stroke: rgb(0, 0, 0, 0), fill: rgb(*color))
      end
      puddle[:rings] << { oval: ring, size: BRUSH * 0.8, color: color }
      sound "ring#{3 + puddle[:rings].size}"
    end
    puddle[:rings].each_with_index do |ring, i|
      biggest = [170 - 20 * i, puddle[:room] - 16 * i].min
      next if ring[:size] >= biggest

      ring[:size] = [ring[:size] + dt * 44, biggest].min
      ring[:oval].style(width: (ring[:size] * 1.1).round(1), height: (ring[:size] * 0.92).round(1))
    end
  end

  # A puddle stops growing when the brush moves on or lets go, and a big one drips.
  def settle_puddle(stroke_now = @stroke)
    puddle = stroke_now && stroke_now[:puddle]
    return unless puddle && !puddle[:done]

    puddle[:done] = true
    outer = puddle[:rings].first
    return unless outer && outer[:size] > 60 && !puddle[:mark].gone

    x, y, size = puddle[:x], puddle[:y], outer[:size]
    puddle[:mark].art.append do
      oval x - size * 0.24, y - size * 0.2, size * 0.26, size * 0.12,
        center: true, stroke: rgb(0, 0, 0, 0), fill: rgb(255, 255, 255, 0.45)
    end
    drips = size > 110 ? [-0.22, 0.18] : [0.05]
    drips.each { |dx| drip(x + dx * size, y + size * 0.38, outer[:color], 12) }
  end

  # Paint that runs down the page and ends in a round drop.
  def drip(x, y, color, width)
    x = x.clamp(PAPER_LEFT + 20, PAPER_RIGHT - 20)
    length = [@luck.rand(40..110), PAPER_BOTTOM - 20 - y].min
    return if length < 12

    run = drop = nil
    mark = put_on_page(x - width, 2) do
      nostroke
      run = rect x - width / 2.0, y, width, width, curve: width / 2.0, fill: rgb(*color)
      drop = oval x, y + width, width * 1.5, width * 1.7, center: true, fill: rgb(*color)
    end
    tween(1.8, mark) do |k|
      reach = length * (1 - (1 - k)**3)
      run.style(height: (width + reach).round(1))
      drop.style(top: (y + width + reach).round(1))
    end
    sound "drip"
  end

  # ---------------------------------------------------------------- stamps and splats

  def stamp(kind, x, y, size = STAMP)
    x, y = keep_on_paper(x, y, size * 0.55)
    mark = put_on_page(x - size * 0.6, 14) {}
    tween(0.55, mark) do |k|
      mark.art.clear { friend(kind, x, y, size * springy(k)) }
    end
    3.times { sparkle(x + @luck.rand(-50..50), y + @luck.rand(-50..50), 14) }
    sound kind.to_s
  end

  # A splat of paint where a key sits on the keyboard: a blob and its droplets,
  # which fly out from the middle.
  def splat(x, y, color, note)
    x, y = keep_on_paper(x, y, 60)
    drops = Array.new(6) do
      angle = @luck.rand * 2 * Math::PI
      reach = @luck.rand(34..54)
      [Math.cos(angle) * reach, Math.sin(angle) * reach, @luck.rand(8..18)]
    end
    blob = flying = nil
    mark = put_on_page(x - 70, 7) do
      nostroke
      fill rgb(*color)
      flying = drops.map { |_, _, d| oval x, y, d, center: true }
      blob = oval x, y, 20, center: true
    end
    tween(0.3, mark) do |k|
      grow = springy(k)
      blob.style(width: (54 * grow).round(1), height: (48 * grow).round(1))
      flying.zip(drops).each { |drop, (dx, dy, _)| drop.move((x + dx * grow).round(1), (y + dy * grow).round(1)) }
    end
    sound "splat#{note}"
  end

  # ---------------------------------------------------------------- sparkles

  # Twenty-four twinkles, used over and over: each grows, shines and shrinks
  # away. When they are all busy, the one nearest its end starts again.
  def sparkle(x, y, size)
    spark = @twinkles.max_by { |t| t[:age] / t[:life] }
    spark.merge!(size: size, age: 0.0, life: 0.8)
    spark[:star].style(left: x.round(1), top: y.round(1), outer: 0.1, inner: 0.1, hidden: false)
    spark[:dot].style(left: x.round(1), top: y.round(1), width: 1, height: 1, hidden: false)
  end

  # While nobody is painting, the paper twinkles now and then, to invite a first touch.
  def invite
    return if @clock - @busy_at < 5 || @clock < @next_invite

    @next_invite = @clock + 1.4
    sparkle(@luck.rand(PAPER_LEFT + 60..PAPER_RIGHT - 60), @luck.rand(PAPER_TOP + 60..PAPER_BOTTOM - 60), 14)
  end

  def twinkle(dt)
    @twinkles.each do |t|
      next if t[:age] >= t[:life]

      t[:age] += dt
      k = t[:age] / t[:life]
      if k >= 1
        t[:star].hide
        t[:dot].hide
        next
      end
      glow = Math.sin(Math::PI * k)
      t[:star].style(outer: (t[:size] * glow).round(1), inner: (t[:size] * glow * 0.3).round(1))
      t[:dot].style(width: (t[:size] * 0.45 * glow).round(1), height: (t[:size] * 0.45 * glow).round(1))
    end
  end

  # ---------------------------------------------------------------- the wave

  # The wave washes in from the left over everything, and everything its crest
  # passes is gone. Then the water runs off to the right, leaving clean paper.
  def wash
    return if @washing

    @washing = 0.0
    end_stroke
    @wave.show
    sound "wave"
  end

  def roll_wave(dt)
    return unless @washing

    @washing += dt
    t = @washing
    span = PAPER_RIGHT - PAPER_LEFT
    crest = PAPER_LEFT + span * smooth([t / 1.3, 1].min)
    trail = PAPER_LEFT + span * smooth((t - 1.05).clamp(0, 0.85) / 0.85)
    width = [crest - trail, 1].max
    @wave_body.style(left: trail.round(1), width: width.round(1))
    lip = [width, 44].min
    @wave_lip.style(left: (crest - lip).round(1), width: lip.round(1))
    fade = ((PAPER_RIGHT - crest) / 70.0).clamp(0, 1) # the foam melts as it reaches the far edge
    @foam.each_with_index do |foam, i|
      size = foam[:size] * fade
      bob = Math.sin(t * 9 + i * 1.7) * 5
      foam[:oval].style(left: (crest - 6 + bob).round(1), width: size.round(1), height: size.round(1), hidden: size < 2)
    end
    @wave_bubbles.each_with_index do |bubble, i|
      x = crest - 40 - (i * 53 + t * 120) % [width - 40, 60].max
      y = PAPER_TOP + 40 + (i * 97 + t * 40 * (i % 3 + 1)) % (PAPER_BOTTOM - PAPER_TOP - 80)
      bubble.style(left: x.round(1), top: y.round(1), hidden: x < trail + 10)
    end
    @ripples.each_with_index do |ripple, i|
      x = crest - 90 - (i * 211 + t * 60) % 700
      y = PAPER_TOP + 60 + i * 64 + Math.sin(t * 5 + i) * 6
      ripple.style(left: x.round(1), top: y.round(1), hidden: x < trail + 8 || x + 72 > crest - 20)
    end
    @riders.each do |rider|
      x = crest - rider[:lag]
      y = rider[:y] + Math.sin(t * 6 + rider[:phase]) * 14
      showing = x > trail + 4
      rider[:slot].move(x.round, y.round) if showing
      rider[:slot].style(hidden: !showing)
    end
    wash_away(t >= 1.3 ? PAPER_RIGHT + BRUSH * 4 : crest)
    return if t < 1.95

    @washing = nil
    @wave.hide
  end

  def wash_away(crest)
    @marks.select { |mark| mark.left < crest - 10 }.each { |mark| forget(mark) }
    @marks.reject!(&:gone)
  end

  # ---------------------------------------------------------------- the tray

  def choose(tool)
    @tool = tool
    @ring.move(TOOL_X, TOOL_Y[tool])
    tween(0.35) do |k|
      size = 88 * (0.8 + 0.2 * springy(k))
      @ring.style(width: size.round(1), height: size.round(1))
    end
    sound "pick"
  end

  def toggle_sound
    @music.muted = !@music.muted
    @sound_parts[:waves].each { |wave| wave.hidden = @music.muted }
    @sound_parts[:cross].each { |line| line.hidden = !@music.muted }
    @sound_disc.fill = @music.muted ? "#e9e4ee" : "#e4f7ea"
    sound "hello"
  end

  # A button in the tray swells a little while the pointer is over it.
  def swell(dt)
    @discs.each do |name, disc|
      rest = name == :sound ? 60 : 74
      want = @hovered == name ? rest + 10 : rest
      was = @disc_sizes[name] ||= rest
      next if (want - was).abs < 0.2

      @disc_sizes[name] = was + (want - was) * [dt * 14, 1].min
      disc.style(width: @disc_sizes[name].round(1), height: @disc_sizes[name].round(1))
    end
  end

  # Which button in the tray is under (x, y), if any.
  def tray_button(x, y)
    buttons = TOOL_Y.merge(wave: WAVE_Y, sound: SOUND_Y)
    buttons.find { |_, by| Math.hypot(x - TOOL_X, y - by) < 42 }&.first
  end

  # ---------------------------------------------------------------- the keyboard

  def press(key)
    return hold_escape if key.to_s == "escape"
    return if @clock - @last_key < 0.06 # a hand mashing keys makes about fifteen a second at most

    @last_key = @clock
    letter = key.is_a?(String) && key.size == 1 ? key.downcase : nil
    row = letter && KEY_ROWS.index { |keys| keys.include?(letter) }
    if row
      column = KEY_ROWS[row].index(letter)
      x = PAPER_LEFT + 80 + column * (PAPER_RIGHT - PAPER_LEFT - 160) / 9.0 + @luck.rand(-26..26)
      y = PAPER_TOP + 80 + row * (PAPER_BOTTOM - PAPER_TOP - 160) / 3.0 + @luck.rand(-26..26)
      if row.zero?
        stamp(TOOLS[1 + column % 4], x, y, STAMP * 0.8)
      else
        @splash += 1
        splat(x, y, RAINBOW[@splash % RAINBOW.size], column + 3 - row)
      end
    else
      kind = @tool == :brush ? TOOLS[1 + @luck.rand(4)] : @tool
      stamp(kind, @luck.rand(PAPER_LEFT..PAPER_RIGHT), @luck.rand(PAPER_TOP..PAPER_BOTTOM))
    end
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
  @luck = Random.new(7)
  @clock = 0.0
  @hue = 0.0
  @tool = :brush
  @marks = []
  @pieces = 0
  @tweens = []
  @splash = 0
  @last_key = -1.0
  @escape_last = -9.0
  @escape_repeats = 0
  @busy_at = 0.0
  @next_invite = 0.0
  # Fredoka beside the app, in fonts/ or _fonts/ (where a packaged app carries it), or in the
  # Kids folder's shared _fonts, as the other Kids apps look.
  font_file = [["Fredoka.ttf"], ["fonts", "Fredoka.ttf"], ["_fonts", "Fredoka.ttf"], ["..", "_fonts", "Fredoka.ttf"]]
    .map { |parts| File.join(__dir__, *parts) }.find { |file| File.exist?(file) }
  rounded = font_file && font(font_file) ? "Fredoka" : "Avenir Next, Helvetica Neue, sans-serif"

  background WALL.."#ffe2ec"

  # the paper, lifted off the wall by a soft shadow
  nostroke
  5.times do |i|
    rect PAPER_LEFT - i, PAPER_TOP + 4 + i, PAPER_RIGHT - PAPER_LEFT + i * 2, PAPER_BOTTOM - PAPER_TOP,
      curve: 28 + i, fill: rgb(150, 90, 60, 0.035)
  end
  rect PAPER_LEFT, PAPER_TOP, PAPER_RIGHT - PAPER_LEFT, PAPER_BOTTOM - PAPER_TOP, curve: 28, fill: PAPER

  # the paint goes here, then sparkles over it, then the wave over everything
  @paint = stack(left: 0, top: 0, width: W, height: H) {}
  @twinkles = []
  stack(left: 0, top: 0, width: W, height: H) do
    nostroke
    @twinkles = Array.new(24) do
      {
        star: star(0, 0, 4, 1, 0.3, fill: rgb(255, 205, 64, 0.95), hidden: true),
        dot: oval(0, 0, 1, center: true, fill: rgb(255, 255, 255, 0.95), hidden: true),
        age: 1.0, life: 1.0,
      }
    end
  end
  @wave = stack(left: 0, top: 0, width: W, height: H, hidden: true) do
    nostroke
    @wave_body = rect PAPER_LEFT, PAPER_TOP, 1, PAPER_BOTTOM - PAPER_TOP, curve: 28, fill: gradient("#8fdcff", "#4a9cf2", angle: 90)
    @wave_lip = rect PAPER_LEFT, PAPER_TOP, 1, PAPER_BOTTOM - PAPER_TOP, curve: 22, fill: rgb(214, 246, 255, 0.9)
    @foam = Array.new(15) do |i|
      size = [34, 46, 28, 40, 52, 30, 44][i % 7]
      { size: size, oval: oval(PAPER_LEFT, PAPER_TOP + 34 + i * 42, size, center: true, fill: white) }
    end
    nofill
    stroke rgb(255, 255, 255, 0.8)
    strokewidth 2
    @wave_bubbles = Array.new(12) { |i| oval(0, 0, 8 + i % 4 * 4, center: true) }
    stroke rgb(255, 255, 255, 0.45)
    strokewidth 4
    cap :curve
    @ripples = Array.new(9) do
      shape(left: 0, top: 0) do
        move_to 0, 6
        curve_to 12, -3, 24, -3, 36, 6
        curve_to 48, 15, 60, 15, 72, 6
      end
    end
    @riders = [[0, 230, 92], [1, 450, 74]].map do |i, y, size|
      rider = stack(left: 0, top: y, width: size * 1.2, height: size) { fish_friend(size * 0.62, size * 0.5, size) }
      { slot: rider, y: y, lag: 110 + i * 170, phase: i * 2.1 }
    end
  end

  # the brush's outline follows the pointer over the paper
  nofill
  strokewidth 3
  @cursor = oval 0, 0, BRUSH + 4, center: true, stroke: rgb(*rainbow(0)), hidden: true

  # the tray
  nostroke
  4.times { |i| rect 20 - i, 24 + i * 2, 104 + i * 2, 636 + i, curve: 44 + i, fill: rgb(150, 90, 60, 0.05) }
  rect 20, 20, 104, 640, curve: 44, fill: "#ffffff".."#fff4e8"
  @ring = oval TOOL_X, TOOL_Y[:brush], 88, center: true, fill: white, stroke: "#ff8fb1", strokewidth: 4
  @discs = {}
  @disc_sizes = {}
  TOOLS.each do |tool|
    nostroke
    @discs[tool] = oval TOOL_X, TOOL_Y[tool], 74, center: true, fill: TOOL_TINT[tool]
    if tool == :brush
      @brush_tip = brush_icon(TOOL_X, TOOL_Y[tool], 62)
    else
      friend(tool, TOOL_X, TOOL_Y[tool], 56)
    end
  end
  nostroke
  @discs[:wave] = oval TOOL_X, WAVE_Y, 76, center: true, fill: "#dff4ff"
  wave_icon(TOOL_X, WAVE_Y + 4, 64)
  @sound_disc = @discs[:sound] = oval TOOL_X, SOUND_Y, 60, center: true, fill: "#e4f7ea"
  @sound_parts = sound_icon(TOOL_X, SOUND_Y, 44)

  # for grown-ups, under the paper
  stack left: PAPER_LEFT + 6, top: PAPER_BOTTOM + 8, width: 300 do
    para "Paint Puddles", size: 17, family: rounded, weight: "bold", stroke: "#b2687f", margin: 0
  end
  stack left: PAPER_RIGHT - 470, top: PAPER_BOTTOM + 12, width: 440 do
    para "Grown-ups: hold Esc for two seconds to close.", align: "right", size: 11, stroke: "#b08a8f", margin: 0
  end
  nofill
  strokewidth 3
  stroke "#b2687f"
  @hold_ring = arc PAPER_RIGHT - 16, PAPER_BOTTOM + 20, 16, 16, -Math::PI / 2, -Math::PI / 2, center: true, hidden: true

  # ---------------------------------------------------------------- hands on

  click do |_button, x, y|
    @busy_at = @clock
    button = tray_button(x, y)
    if button == :wave
      wash
    elsif button == :sound
      toggle_sound
    elsif button
      choose(button)
    elsif on_paper?(x, y)
      @down = true
      @cursor.hide
      if @tool == :brush
        start_stroke(x, y)
      else
        @stamped_at = [x, y]
        stamp(@tool, x, y)
      end
    else
      # a click on the wall around the paper twinkles and sings a little
      3.times { sparkle(x + @luck.rand(-24..24), y + @luck.rand(-24..24), 10) }
      sing(y)
    end
  end

  motion do |x, y|
    over = on_paper?(x, y)
    ring = @tool == :brush ? BRUSH + 4 : 44
    @hovered = tray_button(x, y)
    @cursor.style(left: x.round(1), top: y.round(1), width: ring, height: ring, hidden: !over || @down,
      stroke: rgb(*(@tool == :brush ? rainbow(@hue) : [255, 170, 60])))
    if @stroke
      extend_stroke(x, y)
    elsif @down && @stamped_at
      # dragging with a stamp leaves a trail of friends
      if Math.hypot(x - @stamped_at[0], y - @stamped_at[1]) > 80
        @stamped_at = [x, y]
        stamp(@tool, x, y, STAMP * 0.75)
      end
    elsif over
      # just wiggling the mouse over the paper leaves a trail of twinkles
      @trail ||= [x, y]
      if Math.hypot(x - @trail[0], y - @trail[1]) > 60
        @trail = [x, y]
        sparkle(x, y, 9)
      end
    end
  end

  release do
    @down = false
    @stamped_at = nil
    end_stroke
  end

  keypress do |key|
    @busy_at = @clock
    press(key)
  end

  animate(FPS) do |frame|
    dt = 1.0 / FPS
    @clock = frame * dt
    pool(dt)
    run_tweens(dt)
    twinkle(dt)
    invite
    roll_wave(dt)
    swell(dt)
    watch_escape
  end
end
