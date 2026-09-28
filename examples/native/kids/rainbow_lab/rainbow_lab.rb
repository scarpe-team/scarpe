# Rainbow Lab: pour paint, mix it, and fill a shelf with every colour you find.
#
# Four big pots of paint sit on the counter: red, yellow, blue and white. Tap one, or
# press any key, and a drop leaps into the glass bowl, where it swirls into the paint
# already there. Red and blue make purple, yellow and blue make green, and white makes
# everything paler. The lab shows each colour's name in big letters and plays it a
# little tune, a chameleon on the rim of the bowl turns whatever colour you mix, and
# every colour you find for the first time gets a jar on the rainbow shelf.
#
# It is made for small hands. Nothing can go wrong: every key, every tap and every
# wiggle of the mouse does something, and no reading is needed. The bowl empties
# itself when it is full, or tap the whirlpool to start again. Tap a jar on the shelf
# to see which drops make that colour.
#
# For grown-ups: R, Y, B and W pour those pots (so do 1 to 4), any other key pours one
# of them, Space stirs, Backspace empties the bowl and Enter plays the colour's tune
# again. Hold Escape for two seconds to leave. The shelf is kept in
# ~/Library/Application Support/Rainbow Lab; nothing else is saved or sent anywhere.
#
# The tunes are made right here in plain Ruby: soft music-box notes on a pentatonic
# scale, so any two sound lovely together, written once as small WAV files and played
# with afplay.

require "json"
require "fileutils"
require "tmpdir"

W, H = 960, 720
INK = [61, 52, 86]
SAVE_FILE = File.join(Dir.home, "Library", "Application Support", "Rainbow Lab", "shelf.json")
# Fredoka, the round font the Kids apps share: in fonts or beside the app once it is packaged,
# and in the _fonts folder next door in a Scarpe checkout. Without it the words still show.
FREDOKA = %w[fonts . _fonts ../_fonts].map { |dir| File.expand_path("#{dir}/Fredoka.ttf", __dir__) }.find { |path| File.exist?(path) }

BOWL_X, RIM_Y = 450, 300    # the middle of the bowl's rim
BOWL_RX, BOWL_RY = 190, 172 # the bowl is the bottom half of an oval this wide and this deep
RIM_RY = 34                 # and its rim, seen from a little above, is an oval this tall
FULL = 6                    # the drops the bowl holds; the next one empties it first
COUNTER_Y = 500             # where the wall meets the counter
POT_Y = 560                 # the top of the pots
SHELF_Y = 104               # the top of the shelf the jars stand on
LIZARD_X, LIZARD_Y = 482, 196 # the chameleon's box: it starts 70 pixels left of its nose, for its tongue

# The four pots: their paint, the picture on their label, the keys that pour them,
# and the note each drop plays as it lands.
POTS = [
  { name: :red, paint: [229, 57, 53], picture: :heart, keys: %w[r 1], note: "c5", x: 150 },
  { name: :yellow, paint: [255, 204, 51], picture: :sun, keys: %w[y 2], note: "e5", x: 350 },
  { name: :blue, paint: [47, 128, 237], picture: :raindrop, keys: %w[b 3], note: "g4", x: 550 },
  { name: :white, paint: [255, 255, 255], picture: :cloud, keys: %w[w 4], note: "a5", x: 750 },
]

# Every colour the lab knows, in the order its jar stands on the shelf: the drops
# that make it (red, yellow, blue, white), and its tune.
COLOURS = {
  "Red" => [[1, 0, 0, 0], "g4 c5 e5 g5"],
  "Tomato" => [[2, 1, 0, 0], "g4 e5 c5 e5"],
  "Orange" => [[1, 1, 0, 0], "e5 g5 a5 g5"],
  "Gold" => [[1, 2, 0, 0], "c5 g5 e5 c6"],
  "Yellow" => [[0, 1, 0, 0], "e5 g5 c6"],
  "Lime" => [[0, 2, 1, 0], "d5 e5 g5 e5"],
  "Green" => [[0, 1, 1, 0], "c5 d5 e5 g5"],
  "Teal" => [[0, 1, 2, 0], "a4 c5 e5 d5"],
  "Blue" => [[0, 0, 1, 0], "c5 a4 g4 c5"],
  "Indigo" => [[1, 0, 2, 0], "a4 e5 d5 c5"],
  "Purple" => [[1, 0, 1, 0], "e5 d5 c5 a4"],
  "Berry" => [[2, 0, 1, 0], "g5 e5 g5 a5"],
  "Pink" => [[1, 0, 0, 1], "a5 g5 e5 g5"],
  "Peach" => [[1, 1, 0, 1], "c5 e5 d5 g5"],
  "Lemon" => [[0, 1, 0, 1], "e6 d6 c6 a5"],
  "Mint" => [[0, 1, 1, 1], "d5 g5 a5 c6"],
  "Sky Blue" => [[0, 0, 1, 1], "g5 a5 c6 e6"],
  "Lilac" => [[1, 0, 1, 1], "a5 e5 g5 c6"],
  "Brown" => [[1, 1, 1, 0], "c4 e4 g4 e4"],
  "Biscuit" => [[1, 1, 1, 1], "e4 g4 a4 c5"],
  "White" => [[0, 0, 0, 1], "g5 c6 e6"],
}

# Paint mixes the way a painter's paint does, not the way light does: red and blue
# make purple, yellow and blue make green, and all three make brown.
module Paint
  module_function

  # What each mix of the three primaries makes on its own. Any other mix lands
  # between these corners (this is Gossett and Chen's "RYB cube", in gentler colours).
  CORNERS = {
    [0, 0, 0] => [255, 255, 255],
    [1, 0, 0] => [229, 57, 53],  # red
    [0, 1, 0] => [255, 204, 51], # yellow
    [0, 0, 1] => [47, 128, 237], # blue
    [1, 1, 0] => [255, 138, 30], # orange
    [1, 0, 1] => [142, 76, 196], # purple
    [0, 1, 1] => [67, 178, 88],  # green
    [1, 1, 1] => [126, 84, 58],  # brown
  }
  WHITE = [250, 249, 244]

  # The colour of some drops: [red, yellow, blue, white].
  def mix(drops)
    red, yellow, blue, white = drops
    most = [red, yellow, blue].max
    return WHITE if most.zero?

    amounts = [red, yellow, blue].map { |count| count.fdiv(most) }
    color = [0, 0, 0]
    CORNERS.each do |corner, rgb|
      share = corner.zip(amounts).map { |on, amount| on == 1 ? amount : 1 - amount }.reduce(:*)
      3.times { |i| color[i] += share * rgb[i] }
    end
    lighten(color, 0.8 * white.fdiv(white + most)) # white thins the strongest colour
  end

  def lighten(color, amount) = color.map { |c| (c + (255 - c) * amount).round }
  def darken(color, amount) = color.map { |c| (c * (1 - amount)).round }
  def blend(from, to, amount) = from.zip(to).map { |a, b| a + (b - a) * amount }

  # The name of the colour some drops make: whichever colour on the shelf looks closest.
  def name_of(drops)
    return if drops.sum.zero?

    here = lab(mix(drops))
    LOOKS.min_by { |_, there| here.zip(there).sum { |a, b| (a - b)**2 } }.first
  end

  # CIE Lab: a way of writing colours where equal distances look about equally different.
  def lab(color)
    r, g, b = color.map do |c|
      c /= 255.0
      c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
    end
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    fx, fy, fz = [x, y, z].map { |v| v > 0.008856 ? Math.cbrt(v) : 7.787 * v + 16 / 116.0 }
    [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)]
  end

  # Blends two colours the long way round the colour wheel's edge rather than straight
  # across it, so purple turning green passes through blue instead of grey.
  def around(from, to, amount)
    (h1, s1, l1), (h2, s2, l2) = hsl(from), hsl(to)
    h1 = h2 if s1 < 0.05 # a grey has no hue of its own to start from
    h2 = h1 if s2 < 0.05
    turn = (h2 - h1 + 540) % 360 - 180
    from_hsl((h1 + turn * amount) % 360, s1 + (s2 - s1) * amount, l1 + (l2 - l1) * amount)
  end

  # Hue (0 to 360), saturation and lightness (0 to 1), and back.
  def hsl(color)
    r, g, b = color.map { |c| c / 255.0 }
    high, low = [r, g, b].max, [r, g, b].min
    light = (high + low) / 2
    return [0.0, 0.0, light] if high == low

    spread = high - low
    sat = light > 0.5 ? spread / (2 - high - low) : spread / (high + low)
    hue = if high == r then (g - b) / spread % 6 elsif high == g then (b - r) / spread + 2 else (r - g) / spread + 4 end
    [hue * 60, sat, light]
  end

  def from_hsl(hue, sat, light)
    chroma = (1 - (2 * light - 1).abs) * sat
    x = chroma * (1 - (hue / 60 % 2 - 1).abs)
    r, g, b = [[chroma, x, 0], [x, chroma, 0], [0, chroma, x], [0, x, chroma], [x, 0, chroma], [chroma, 0, x]][(hue / 60).floor % 6]
    m = light - chroma / 2
    [r, g, b].map { |c| (c + m) * 255 }
  end

  # True when dark writing reads better on this colour than white writing does.
  def light?(color) = lab(color).first > 66

  LOOKS = COLOURS.to_h { |name, (drops, _)| [name, lab(mix(drops))] }
end

# The lab's voice. Each sound is worked out once as numbers, written to a small WAV
# file, and played in the background with afplay while the app carries on.
class Chimes
  RATE = 22_050
  TAU = 2 * Math::PI
  PEAK = 0.25   # the loudest any sound is written: a quarter of full scale
  AT_ONCE = 3   # at most three sounds at a time, so mashing never piles them up
  STEPS = { "c" => 0, "d" => 2, "e" => 4, "f" => 5, "g" => 7, "a" => 9, "b" => 11 }

  attr_reader :last_file, :player
  attr_accessor :muted

  def initialize
    @dir = Dir.mktmpdir("rainbow-lab")
    at_exit { FileUtils.rm_rf(@dir) }
    @files = {}
    @notes = {}
    @playing = []
    @muted = false
  end

  # Plays a tune like "c5 e5 g5": one note every `gap` seconds, in one of the voices
  # below, `level` of the way up to the loudest.
  def tune(notes, voice: :bell, gap: 0.16, level: 1.0)
    return if @muted

    @playing.select!(&:alive?)
    return if @playing.size >= AT_ONCE

    name = "#{voice}-#{notes.tr(" ", "-")}-#{(gap * 1000).round}-#{(level * 100).round}"
    @last_file = @files[name] ||= write(name, mix(notes.split, voice, gap, level))
    @player = Process.detach(spawn("afplay", @last_file, out: File::NULL, err: File::NULL))
    @playing << @player
  rescue SystemCallError
    # no afplay here (not a Mac): the lab is quiet, and just as colourful
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
    sound(1.3) do |t|
      (Math.sin(TAU * hz * t) + 0.22 * Math.sin(TAU * 2 * hz * t) * Math.exp(-t * 6) +
        0.07 * Math.sin(TAU * 3 * hz * t) * Math.exp(-t * 10)) * Math.exp(-t * 3.2)
    end
  end

  # A drop landing in water: a round note that swoops up and away.
  def plip(hz)
    phase = 0.0
    sound(0.3) do |t|
      phase += hz * (1.9 - 0.9 * Math.exp(-t * 30)) / RATE
      Math.sin(TAU * phase) * Math.exp(-t * 13)
    end
  end

  # A soft hum, for gentle answers.
  def hum(hz)
    sound(0.5) { |t| Math.sin(TAU * hz * t) * Math.sin(Math::PI * t / 0.5) }
  end

  # `seconds` of sound, with a soft start and a gentle last fade, so nothing clicks.
  def sound(seconds)
    count = (RATE * seconds).round
    Array.new(count) do |i|
      yield(i.fdiv(RATE)) * [i / (0.012 * RATE), 1, (count - i) / (0.04 * RATE)].min
    end
  end

  # "a4" is 440 Hz, and each semitone up is the twelfth root of two higher.
  def hz(note)
    440 * 2**((STEPS.fetch(note[0]) + 12 * (note[1..].to_i + 1) - 69) / 12.0)
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

Shoes.app(title: "Rainbow Lab", width: W, height: H, resizable: false) do
  # ---- small helpers ----

  def paint(color, alpha = 1.0) = rgb(*color.map(&:round), alpha)
  def ease_out(p) = 1 - (1 - p)**3

  # How far across the bowl the paint's surface reaches when it sits at height y.
  def half_width_at(y)
    BOWL_RX * Math.sqrt([1 - ((y - RIM_Y) / BOWL_RY.to_f)**2, 0].max)
  end

  def surface_y = RIM_Y + BOWL_RY * (1 - 0.82 * @level)

  # ---- pictures: the pots wear these, so no one has to read which pot is which ----

  def picture(kind, x, y, size, color)
    s = size
    nostroke
    case kind
    when :heart
      shape(fill: color) do
        move_to x, y + s * 0.4
        curve_to x - s * 0.62, y - s * 0.02, x - s * 0.34, y - s * 0.62, x, y - s * 0.22
        curve_to x + s * 0.34, y - s * 0.62, x + s * 0.62, y - s * 0.02, x, y + s * 0.4
      end
    when :sun
      oval x, y, s * 0.5, center: true, fill: color
      8.times do |i|
        a = i * Math::PI / 4
        line x + Math.cos(a) * s * 0.36, y + Math.sin(a) * s * 0.36, x + Math.cos(a) * s * 0.5, y + Math.sin(a) * s * 0.5,
          stroke: color, strokewidth: s * 0.1, cap: :round
      end
    when :raindrop
      shape(fill: color) do
        move_to x, y - s * 0.5
        curve_to x + s * 0.1, y - s * 0.26, x + s * 0.36, y - s * 0.04, x + s * 0.36, y + s * 0.16
        curve_to x + s * 0.36, y + s * 0.38, x + s * 0.2, y + s * 0.5, x, y + s * 0.5
        curve_to x - s * 0.2, y + s * 0.5, x - s * 0.36, y + s * 0.38, x - s * 0.36, y + s * 0.16
        curve_to x - s * 0.36, y - s * 0.04, x - s * 0.1, y - s * 0.26, x, y - s * 0.5
      end
    when :cloud
      oval x - s * 0.22, y + s * 0.06, s * 0.42, center: true, fill: color
      oval x + s * 0.06, y - s * 0.08, s * 0.54, center: true, fill: color
      oval x + s * 0.3, y + s * 0.1, s * 0.34, center: true, fill: color
      rect x - s * 0.42, y + s * 0.06, s * 0.86, s * 0.21, curve: s * 0.1, fill: color
    end
  end

  # The line around a pot's paint: a deeper shade of it (and a soft lilac for white).
  def edge_of(pot)
    pot[:name] == :white ? paint([186, 178, 210]) : paint(Paint.darken(pot[:paint], 0.28))
  end

  # The colour a pot's picture is drawn in: its own paint, deep enough to see on white.
  def picture_ink(pot)
    pot[:name] == :white ? paint([150, 170, 205]) : paint(Paint.darken(pot[:paint], pot[:name] == :yellow ? 0.18 : 0))
  end

  # ---- the room ----

  def room
    background paint([255, 247, 234])..paint([241, 232, 255])
    nostroke
    [[90, 250, 160, [255, 190, 200]], [830, 210, 220, [190, 225, 255]], [700, 430, 120, [255, 230, 170]],
     [250, 470, 90, [200, 240, 210]], [880, 470, 70, [230, 205, 255]]].each do |x, y, d, color|
      oval x, y, d, center: true, fill: paint(color, 0.35)
    end
    # the counter everything stands on
    rect 0, COUNTER_Y, W, H - COUNTER_Y, fill: paint([246, 222, 196])..paint([233, 196, 160])
    rect 0, COUNTER_Y, W, 5, fill: paint([255, 240, 222])
    rect 0, COUNTER_Y + 5, W, 3, fill: paint([200, 160, 125], 0.35)
  end

  def shelf
    nostroke
    rect 36, SHELF_Y + 12, 888, 6, curve: 3, fill: paint([150, 100, 70], 0.18)
    rect 36, SHELF_Y, 888, 13, curve: 4, fill: paint([214, 160, 112])..paint([181, 124, 82])
    rect 36, SHELF_Y, 888, 3, curve: 2, fill: paint([236, 196, 150])
    [110, 850].each do |x|
      shape(fill: paint([181, 124, 82])) { move_to x - 10, SHELF_Y + 13; line_to x + 10, SHELF_Y + 13; line_to x, SHELF_Y + 34; line_to x - 10, SHELF_Y + 13 }
    end
    @jars = {}
    COLOURS.each_key.with_index do |name, i|
      x = 60 + i * 42
      jar = { x: x, spring: Spring.new, name: name }
      jar[:slot] = stack(left: x - 16, top: SHELF_Y - 46, width: 32, height: 46) { jar_art(jar) }
      jar[:slot].click { tap_jar(name) }
      @jars[name] = jar
      fill_jar(jar, name) if @found.include?(name)
    end
  end

  # A little glass jar: empty and faint until its colour is found, then full, with a cork.
  def jar_art(jar)
    nostroke
    jar[:glass] = rect 2, 10, 28, 36, curve: 9, fill: paint([255, 255, 255], 0.45), stroke: paint(INK, 0.16), strokewidth: 2
    jar[:paint] = rect 5, 17, 22, 26, curve: 7, hidden: true
    jar[:shine] = rect 8, 20, 4, 16, curve: 2, fill: paint([255, 255, 255], 0.6), hidden: true
    jar[:lid] = rect 5, 3, 22, 9, curve: 3, fill: paint(INK, 0.1)
    jar
  end

  def fill_jar(jar, name)
    color = Paint.mix(COLOURS[name][0])
    jar[:paint].style(fill: paint(color)..paint(Paint.darken(color, 0.12)), hidden: false)
    jar[:shine].show
    jar[:glass].style(stroke: paint(Paint.darken(color, 0.35), 0.8))
    jar[:lid].style(fill: paint([214, 160, 112])..paint([181, 124, 82]))
  end

  # ---- the pots ----

  def pots
    POTS.each do |pot|
      pot[:shadow] = oval pot[:x], H - 34, 118, 20, center: true, fill: paint([120, 80, 50], 0.16)
      pot[:spring] = Spring.new
      pot[:slot] = stack(left: pot[:x] - 65, top: POT_Y, width: 130, height: 136) { pot_art(pot) }
      pot[:slot].click { pour(pot) }
      pot[:slot].hover { pot[:spring].kick(-90) }
    end
  end

  def pot_art(pot)
    color = pot[:paint]
    edge = pot[:name] == :white ? paint([186, 178, 210]) : paint(Paint.darken(color, 0.3))
    top = pot[:name] == :white ? [242, 240, 250] : Paint.lighten(color, 0.2)
    nostroke
    rect 12, 34, 106, 98, curve: 32, fill: paint(Paint.lighten(color, 0.1))..paint(Paint.darken(color, 0.1)), stroke: edge, strokewidth: 3
    oval 6, 18, 118, 34, fill: paint(top), stroke: edge, strokewidth: 3
    oval 20, 25, 90, 20, fill: paint(color)
    rect 90, 42, 11, 30, curve: 5.5, fill: paint(top)
    oval 95.5, 72, 14, center: true, fill: paint(top)
    rect 22, 52, 9, 58, curve: 4.5, fill: paint([255, 255, 255], 0.4)
    oval 65, 90, 60, center: true, fill: white, stroke: pot[:name] == :white ? paint([216, 210, 234]) : paint([255, 255, 255]), strokewidth: 2
    picture(pot[:picture], 65, 90, 40, picture_ink(pot))
  end

  # ---- the bowl ----

  def bowl_back
    nostroke
    oval BOWL_X, 526, 250, 34, center: true, fill: paint([120, 80, 50], 0.14)
    oval BOWL_X, 520, 150, 28, center: true, fill: paint([255, 255, 255], 0.55), stroke: paint(INK, 0.12), strokewidth: 2
    rect BOWL_X - 20, 462, 40, 56, fill: paint([255, 255, 255], 0.5)
    arc BOWL_X - BOWL_RX, RIM_Y - BOWL_RY, BOWL_RX * 2, BOWL_RY * 2, 0, Math::PI, fill: paint([255, 255, 255], 0.35)
    oval BOWL_X, RIM_Y, BOWL_RX * 2, RIM_RY * 2, center: true, fill: paint([255, 255, 255], 0.25)
  end

  # The paint: its body is the bowl's own oval cut straight across at the surface, and
  # the surface is an oval on top of that.
  def paint_layer
    nostroke
    @body = arc BOWL_X - BOWL_RX, RIM_Y - BOWL_RY, BOWL_RX * 2, BOWL_RY * 2, 1.5, 1.6, hidden: true
    @surface = oval BOWL_X, RIM_Y + BOWL_RY, 10, 4, center: true, hidden: true
    @swirl = Array.new(16) { oval(BOWL_X, RIM_Y, 10, center: true, hidden: true) }
    strokewidth 2.5
    @ripples = Array.new(3) { { art: oval(0, 0, 10, 4, center: true, fill: paint([255, 255, 255], 0), stroke: paint([255, 255, 255], 0), hidden: true), age: 9.0 } }
    @bubbles = Array.new(4) { { art: oval(0, 0, 8, center: true, fill: paint([255, 255, 255], 0.4), hidden: true), age: 9.0 } }
  end

  def bowl_front
    nofill
    strokewidth 3
    arc BOWL_X - BOWL_RX, RIM_Y - BOWL_RY, BOWL_RX * 2, BOWL_RY * 2, 0, Math::PI, stroke: paint(INK, 0.2)
    arc BOWL_X - BOWL_RX, RIM_Y - RIM_RY, BOWL_RX * 2, RIM_RY * 2, 0, Math::PI, stroke: paint([255, 255, 255], 0.95), strokewidth: 4
    arc BOWL_X - BOWL_RX, RIM_Y - RIM_RY, BOWL_RX * 2, RIM_RY * 2, Math::PI, 2 * Math::PI, stroke: paint(INK, 0.14), strokewidth: 2
    strokewidth 7
    shape(stroke: paint([255, 255, 255], 0.6), cap: :round) do
      move_to BOWL_X - 160, RIM_Y + 40
      curve_to BOWL_X - 150, RIM_Y + 90, BOWL_X - 118, RIM_Y + 126, BOWL_X - 80, RIM_Y + 146
    end
    nostroke
    oval BOWL_X + 140, RIM_Y + 70, 9, center: true, fill: paint([255, 255, 255], 0.7)
  end

  # Moves the paint to its level and colour for this frame.
  def show_paint
    if @level < 0.005
      [@body, @surface, *@swirl].each(&:hide) unless @paint_hidden
      @paint_hidden = true
      @painted = nil
      return
    end
    @paint_hidden = false
    y = surface_y
    half = half_width_at(y)
    show_swirl(y, half)
    look = [y.round(1), @shown.map(&:round)]
    return if look == @painted # nothing has changed since the last frame

    @painted = look
    angle = Math.asin(((y - RIM_Y) / BOWL_RY).clamp(-1, 1))
    color = @shown
    @body.style(angle1: angle, angle2: Math::PI - angle, hidden: false,
      fill: paint(Paint.lighten(color, 0.06))..paint(Paint.darken(color, 0.16)))
    @surface.style(left: BOWL_X, top: y, width: half * 2, height: half * 0.36,
      fill: paint(Paint.lighten(color, 0.16)), hidden: false)
  end

  # Fresh paint swirls around the surface in a spiral and slowly melts into the mix:
  # a ribbon of blobs, each a little further out and a little further round.
  def show_swirl(y, half)
    color = Paint.blend(@swirl_color, @shown, 1 - @swirl_strength)
    last = @swirl.size - 1.0
    return if @swirl_strength < 0.05 && @swirl_hidden

    @swirl_hidden = @swirl_strength < 0.05
    @swirl.each_with_index do |blob, i|
      next blob.hide if @swirl_hidden

      along = i / last
      reach = (0.06 + 0.78 * along) * half * (0.55 + 0.45 * @swirl_strength)
      angle = @spin + along * 4.4
      size = (12 + 32 * along) * (0.35 + 0.65 * @swirl_strength)
      blob.style(left: (BOWL_X + Math.cos(angle) * reach).round(1), top: (y + Math.sin(angle) * reach * 0.18).round(1),
        width: size.round(1), height: (size * 0.34).round(1), fill: paint(color, 0.95 * @swirl_strength**0.5), hidden: false)
    end
  end

  # ---- the chameleon who lives on the rim, and turns the colour of the paint ----

  def chameleon
    @skin = []
    @lizard = { spring: Spring.new(stiffness: 260, damping: 10), look: [0, 0], blink_at: 3.0 }
    @lizard[:slot] = stack(left: LIZARD_X, top: LIZARD_Y, width: 310, height: 210) { lizard_art }
    paint_lizard(@lizard_color)
    @painted_lizard = @lizard_color
  end

  def skin(art, shade)
    @skin << [art, shade]
    art
  end

  def lizard_art
    # the tail curls in a spiral, in three pieces that get thinner towards the tip
    spiral = (0..60).map do |i|
      along = i / 60.0
      angle = -2.3 + along * 3 * Math::PI
      radius = 52 * (1 - 0.78 * along)
      [218 + Math.cos(angle) * radius, 132 + Math.sin(angle) * radius]
    end
    tail = [[spiral[0..22], 20], [spiral[21..42], 14], [spiral[41..60], 9]]
    curl = ->(points) { proc { move_to(*points.first); points.drop(1).each { |x, y| line_to x, y } } }
    body = proc do
      move_to 106, 100
      curve_to 102, 68, 130, 46, 154, 52
      curve_to 176, 56, 188, 80, 182, 102
      curve_to 162, 118, 126, 118, 106, 100
    end
    head = proc do
      move_to 116, 62
      curve_to 110, 38, 88, 40, 80, 58
      curve_to 72, 70, 64, 82, 66, 90
      curve_to 76, 104, 100, 108, 118, 100
      curve_to 124, 88, 124, 74, 116, 62
    end
    legs = [[116, 104, 114, 128], [166, 106, 166, 124]]
    nostroke
    # an outline first, a little bigger, then the skin on top, so the pieces join up seamlessly
    nofill
    tail.each { |points, width| skin(shape(strokewidth: width + 5, cap: :round, &curl.(points)), :edge_stroke) }
    skin(shape(stroke: black, strokewidth: 5, &body), :edge_both)
    skin(shape(stroke: black, strokewidth: 5, &head), :edge_both)
    legs.each { |x1, y1, x2, y2| skin(line(x1, y1, x2, y2, strokewidth: 13, cap: :round), :edge_stroke) }
    tail.each { |points, width| skin(shape(strokewidth: width, cap: :round, &curl.(points)), :skin_stroke) }
    skin(shape(&body), :skin)
    skin(shape(&head), :skin)
    legs.each { |x1, y1, x2, y2| skin(line(x1, y1, x2, y2, strokewidth: 8, cap: :round), :skin_stroke) }
    [[110, 128], [120, 128], [162, 124], [172, 124]].each { |x, y| skin(oval(x, y, 8, center: true), :shade) }
    # a darker belly, a crest along the back, and freckles
    skin(shape { move_to 110, 102; curve_to 130, 114, 162, 114, 180, 100; curve_to 162, 108, 130, 108, 110, 102 }, :shade)
    [[126, 50, 7], [138, 46, 8], [151, 47, 8], [164, 51, 7], [174, 58, 6]].each { |x, y, d| skin(oval(x, y, d, center: true), :shade) }
    [[140, 78, 13], [158, 72, 10], [166, 92, 9], [130, 94, 8]].each { |x, y, d| skin(oval(x, y, d, center: true), :light) }
    oval 88, 88, 12, 7, center: true, fill: rgb(255, 120, 150, 0.45)
    # the eye on its turret, which follows whatever is moving
    skin(oval(96, 68, 26, center: true, stroke: black, strokewidth: 2), :turret)
    oval 96, 68, 15, center: true, fill: white
    @lizard[:pupil] = oval 96, 68, 7.5, center: true, fill: paint(INK)
    oval 94, 66, 2.5, center: true, fill: white
    @lizard[:lid] = skin(oval(96, 68, 17, center: true, hidden: true), :skin)
    strokewidth 2.2
    shape(stroke: paint(INK, 0.75), cap: :round) { move_to 68, 92; curve_to 78, 97, 88, 97, 98, 94 }
    nostroke
    @lizard[:tongue] = line(68, 92, 68, 92, stroke: rgb(255, 110, 150), strokewidth: 5, cap: :round, hidden: true)
    @lizard[:tip] = oval(68, 92, 11, center: true, fill: rgb(255, 110, 150), hidden: true)
    # tapping the chameleon anywhere tickles it
    [oval(142, 80, 130, 90, center: true), oval(218, 134, 110, 110, center: true)].each do |spot|
      spot.style(fill: rgb(0, 0, 0, 0))
      spot.click { tickle }
    end
  end

  # The whirlpool and the sound switch have their own jobs, so taps on them make no sparkles.
  def on_button?(x, y) = Math.hypot(x - 140, y - 386) < 50 || Math.hypot(x - 906, y - 668) < 34

  def on_lizard?(x, y)
    x -= LIZARD_X
    y -= LIZARD_Y + @lizard[:spring].at * 0.15
    ((x - 142) / 65.0)**2 + ((y - 80) / 45.0)**2 <= 1 || ((x - 218) / 55.0)**2 + ((y - 134) / 55.0)**2 <= 1
  end

  # Every scale of the chameleon takes on a shade of `color`.
  def paint_lizard(color)
    edge = Paint.darken(color, 0.42)
    shades = {
      skin: color, shade: Paint.darken(color, 0.16), light: Paint.lighten(color, 0.3), turret: Paint.lighten(color, 0.1),
    }
    @skin.each do |art, shade|
      case shade
      when :edge then art.fill = paint(edge)
      when :edge_both then art.style(fill: paint(edge), stroke: paint(edge))
      when :edge_stroke then art.stroke = paint(edge)
      when :skin_stroke then art.stroke = paint(color)
      when :turret then art.style(fill: paint(shades[:turret]), stroke: paint(edge))
      else art.fill = paint(shades.fetch(shade))
      end
    end
  end

  # ---- the name of the colour, big, on a paint-chip card ----

  def name_card
    @chip_spring = Spring.new(stiffness: 260, damping: 11)
    @chip = stack(left: BOWL_X - 170, top: 132, width: 340, height: 84, hidden: true) do
      nostroke
      rect 4, 8, 332, 74, curve: 37, fill: paint(INK, 0.12)
      @chip_card = rect 0, 0, 332, 74, curve: 37
      rect 18, 8, 296, 22, curve: 11, fill: paint([255, 255, 255], 0.22)
      @chip_name = para "", font: "Fredoka", size: 40, weight: 600, align: "center", width: 332, margin: [0, 8, 0, 0]
    end
    @chip.click { sing_again }
    @recipe = stack(left: BOWL_X - 120, top: 222, width: 240, height: 34) {}
  end

  def show_name(name, drops)
    color = Paint.mix(COLOURS[name][0])
    @chip_card.fill = paint(color)
    @chip_name.style(stroke: Paint.light?(color) ? paint(INK) : white)
    @chip_name.replace(name)
    @chip.show
    @chip_spring.kick(-420)
    show_recipe(drops)
  end

  # The drops that make a colour, as a row of little drops wearing their pictures.
  def show_recipe(drops)
    list = drops.flat_map.with_index { |count, i| [POTS[i]] * count }.first(FULL)
    @recipe_shown = list.map { |pot| pot[:name] }
    @recipe.clear do
      left = 120 - list.size * 17
      list.each_with_index do |pot, i|
        x = left + 17 + i * 34
        nostroke
        oval x, 17, 30, center: true, fill: paint(pot[:paint]), stroke: edge_of(pot), strokewidth: 2
        picture(pot[:picture], x, 17, 16, pot[:name] == :white ? picture_ink(pot) : white)
      end
    end
  end

  def hide_recipe
    @recipe_shown = []
    @recipe.clear
  end

  # ---- buttons: the whirlpool that empties the bowl, and the sound switch ----

  def buttons
    nostroke
    oval 140, 392, 96, center: true, fill: paint(INK, 0.1)
    oval 140, 386, 96, center: true, fill: white, stroke: paint([190, 220, 245]), strokewidth: 3
    spiral = (0..60).map do |i|
      a = i * 0.21
      r = 4 + i * 0.52
      [140 + Math.cos(a) * r, 386 + Math.sin(a) * r]
    end
    shape(stroke: paint([47, 128, 237]), strokewidth: 6, cap: :round) do
      move_to(*spiral.first)
      spiral.drop(1).each { |x, y| line_to x, y }
    end
    hit = oval 140, 386, 100, center: true, fill: paint([255, 255, 255], 0)
    hit.click { empty_bowl }

    oval 906, 672, 62, center: true, fill: paint(INK, 0.1)
    oval 906, 668, 62, center: true, fill: white
    fill paint(INK)
    rect 888, 660, 10, 16, curve: 2
    shape { move_to 894, 660; line_to 906, 651; line_to 906, 685; line_to 894, 676; line_to 894, 660 }
    nofill
    strokewidth 3.5
    @waves = [arc(904, 658, 20, 20, -0.9, 0.9, stroke: paint(INK), cap: :round), arc(900, 651, 34, 34, -0.8, 0.8, stroke: paint(INK), cap: :round)]
    @hush = [line(912, 660, 924, 676, stroke: paint(INK), cap: :round, hidden: true), line(924, 660, 912, 676, stroke: paint(INK), cap: :round, hidden: true)]
    nostroke
    hit = oval 906, 668, 66, center: true, fill: paint([255, 255, 255], 0)
    hit.click { toggle_sound }
  end

  # ---- pouring ----

  # A pot hops and a drop leaps out of it. However fast the keys come, a drop leaves
  # at most every tenth of a second; the pots hop for every one.
  def pour(pot)
    pot[:spring].kick(-260)
    return if @t - @last_pour < 0.1 || @drops_flying.size >= 6

    @last_pour = @t
    body = shine = nil
    @flight_layer.append do
      nostroke
      body = oval(pot[:x], POT_Y + 30, 30, center: true, fill: paint(pot[:paint]), stroke: edge_of(pot), strokewidth: 2.5)
      shine = oval(pot[:x] - 6, POT_Y + 23, 8, center: true, fill: paint([255, 255, 255], 0.85))
    end
    target = BOWL_X + rand(-0.45..0.45) * half_width_at(surface_y)
    @drops_flying << { pot: pot, body: body, shine: shine, from: [pot[:x], POT_Y + 30], to_x: target, age: 0.0 }
  end

  def fly_drops(dt)
    @drops_flying.each do |drop|
      drop[:age] += dt
      p = [drop[:age] / 0.7, 1].min
      x0, y0 = drop[:from]
      y1 = surface_y
      x = x0 + (drop[:to_x] - x0) * p
      y = y0 + (y1 - y0) * p - 290 * 4 * p * (1 - p)
      speed = ((y1 - y0) - 290 * 4 * (1 - 2 * p)).abs
      stretch = 1 + speed / 3500.0
      drop[:body].style(left: x, top: y, width: 30 / stretch, height: 30 * stretch)
      drop[:shine].style(left: x - 6, top: y - 7 * stretch)
      land(drop, x) if p >= 1
    end
    @drops_flying.reject! { |drop| drop[:landed] }
  end

  def land(drop, x)
    drop[:landed] = true
    drop[:body].remove
    drop[:shine].remove
    pot = drop[:pot]
    fresh_bowl if @drops.sum >= FULL
    @drops[POTS.index(pot)] += 1
    @target = Paint.mix(@drops)
    @shown = pot[:paint] if @level < 0.01 || @drops.sum == 1
    @swirl_color = pot[:paint]
    @swirl_strength = 1.0
    @spin_speed = 5.0
    @level_goal = @drops.sum.fdiv(FULL)
    @chimes.tune(pot[:note], voice: :plip, level: 0.8)
    y = surface_y
    ripple(x, y)
    6.times { splash(x, y, pot[:paint]) }
    @first_waiting ||= @t
    @announce_at = [@t + 0.35, @first_waiting + 0.8].min # say the name once the paint settles
  end

  # ---- naming the colour, and finding new ones ----

  def announce
    @announce_at = @first_waiting = nil
    name = Paint.name_of(@drops)
    return unless name

    @name = name
    show_name(name, @drops)
    @lizard[:spring].kick(-160)
    if @found.include?(name)
      @chimes.tune(COLOURS[name][1])
      @jars[name][:spring].kick(-150)
    else
      discover(name)
    end
  end

  def discover(name)
    @found << name
    save_shelf
    @chimes.tune(COLOURS[name][1])
    timer(0.75) { @chimes.tune("c5 e5 g5 c6", gap: 0.07, level: 0.55) }
    flick_tongue
    send_jar(name)
    celebrate_rainbow if @found.size == COLOURS.size
  end

  # A jar full of the new colour leaps from the bowl up onto its place on the shelf.
  def send_jar(name)
    land_jar if @flying_jar
    slot = nil
    @jar_layer.append do
      slot = stack(left: BOWL_X - 16, top: surface_y - 30, width: 32, height: 46) { fill_jar(jar_art({}), name) }
    end
    @flying_jar = { name: name, slot: slot, from: [BOWL_X - 16, surface_y - 30], to: [@jars[name][:x] - 16, SHELF_Y - 46], age: 0.0 }
  end

  def fly_jar(dt)
    return unless @flying_jar

    jar = @flying_jar
    jar[:age] += dt
    p = ease_out([jar[:age] / 1.0, 1].min)
    (x0, y0), (x1, y1) = jar[:from], jar[:to]
    jar[:slot].move((x0 + (x1 - x0) * p).round(1), (y0 + (y1 - y0) * p - 120 * Math.sin(Math::PI * p)).round(1))
    land_jar if p >= 1
  end

  def land_jar
    jar = @flying_jar
    @flying_jar = nil
    jar[:slot].remove
    fill_jar(@jars[jar[:name]], jar[:name])
    @jars[jar[:name]][:spring].kick(-200)
    x = @jars[jar[:name]][:x]
    8.times { |i| sparkle(x, SHELF_Y - 24, i * Math::PI / 4) }
  end

  # When every jar is full, a rainbow grows behind the bowl.
  def celebrate_rainbow
    @rainbow_bands.each { |band| band.style(angle2: Math::PI) }
    @rainbow.show
    @rainbow_grow = 0.0
    timer(1.2) { @chimes.tune("c5 d5 e5 g5 a5 c6 d6 e6", gap: 0.11) }
  end

  def rainbow_art
    colors = [[229, 57, 53], [255, 138, 30], [255, 204, 51], [67, 178, 88], [47, 128, 237], [96, 92, 210], [142, 76, 196]]
    nofill
    @rainbow_bands = colors.each_with_index.map do |color, i|
      r = 300 - i * 16
      arc BOWL_X - r, 330 - r, r * 2, r * 2, Math::PI, 2 * Math::PI, stroke: paint(color, 0.55), strokewidth: 16
    end
  end

  # The bands sweep across from left to right, the outside one first.
  def grow_rainbow(dt)
    return unless @rainbow_grow

    @rainbow_grow += dt / 1.8
    @rainbow_bands.each_with_index do |band, i|
      sweep = ease_out((@rainbow_grow * 1.4 - i * 0.06).clamp(0, 1))
      band.style(angle2: Math::PI * (1 + sweep))
    end
    @rainbow_grow = nil if @rainbow_grow >= 1
  end

  # ---- emptying and stirring ----

  def empty_bowl
    return if @drops.sum.zero? && @level < 0.01

    @drops = [0, 0, 0, 0]
    @level_goal = 0.0
    @spin_speed = 12.0
    @swirl_color = Paint.lighten(@shown, 0.3)
    @swirl_strength = 1.0
    @draining = true
    @chip.hide
    hide_recipe
    @name = nil
    @announce_at = @first_waiting = nil
    @chimes.tune("g5 e5 d5 c5 a4 g4", voice: :plip, gap: 0.08, level: 0.7)
  end

  # A full bowl swirls itself clean just as the next drop lands, so there is always room.
  def fresh_bowl
    @drops = [0, 0, 0, 0]
    @chip.hide
    hide_recipe
    @chimes.tune("g5 e5 c5", voice: :plip, gap: 0.08, level: 0.6)
  end

  def stir
    return tickle if @level < 0.01

    @spin_speed = 9.0
    @swirl_color = Paint.lighten(@shown, 0.35)
    @swirl_strength = [@swirl_strength, 0.8].max
    3.times { bubble }
    @chimes.tune("c6 a5 e6 g5", voice: :plip, gap: 0.07, level: 0.45)
  end

  # A pointer moving over the paint stirs it a little.
  def stir_gently
    return if @level < 0.01

    @spin_speed = [@spin_speed + 0.8, 5].min
    return if @swirl_strength > 0.4

    @swirl_color = Paint.lighten(@shown, 0.3)
    @swirl_strength = 0.4
  end

  def tickle
    @lizard[:spring].kick(-240)
    @rainbow_skin = 0.0
    flick_tongue
    @chimes.tune("e5 g5 e5 a5 c6", voice: :plip, gap: 0.06, level: 0.5)
  end

  def flick_tongue
    @lizard[:tongue_age] = 0.0
  end

  # ---- every frame ----

  def move_paint(dt)
    @level += (@level_goal - @level) * (1 - Math.exp(-dt * (@draining ? 3.5 : 7)))
    @draining = false if @draining && @level < 0.01
    @shown = Paint.blend(@shown, @target, 1 - Math.exp(-dt * 2.6)) unless @draining
    @spin += @spin_speed * dt
    @spin_speed += (1.2 - @spin_speed) * (1 - Math.exp(-dt * 1.5))
    @swirl_strength *= Math.exp(-dt * (@draining ? 2.5 : 1.1))
    show_paint
    move_ripples(dt)
    move_bubbles(dt)
  end

  def ripple(x, y)
    ring = @ripples.max_by { |r| r[:age] }
    ring.merge!(age: 0.0, x: x, y: y)
  end

  def move_ripples(dt)
    @ripples.each do |ring|
      next if ring[:age] > 1

      ring[:age] += dt / 0.9
      d = 12 + 110 * ease_out([ring[:age], 1].min)
      fade = [1 - ring[:age], 0].max
      ring[:art].style(left: ring[:x], top: surface_y, width: d, height: d * 0.18,
        stroke: paint([255, 255, 255], 0.7 * fade), hidden: ring[:age] > 1 || @level < 0.01)
    end
  end

  def bubble
    b = @bubbles.max_by { |one| one[:age] }
    b.merge!(age: 0.0, x: BOWL_X + rand(-0.5..0.5) * half_width_at(surface_y + 30), y: [surface_y + 70, RIM_Y + BOWL_RY - 16].min, size: rand(5.0..10.0))
  end

  def move_bubbles(dt)
    bubble if @level > 0.3 && rand < dt * 0.8
    @bubbles.each do |b|
      next if b[:age] > 1

      b[:age] += dt / 1.2
      b[:y] -= 38 * dt
      done = b[:y] < surface_y || @level < 0.2
      b[:age] = 9.0 if done
      b[:art].style(left: (b[:x] + Math.sin(b[:age] * 9) * 2).round(1), top: b[:y].round(1), width: b[:size].round(1), height: b[:size].round(1), hidden: done)
    end
  end

  # Little things that fly about: splashes, sparkles and the mouse's trail of bubbles.
  # The next free one of a pool of things, or the one nearest the end of its life.
  def free(pool) = pool.find { |one| one[:age] >= one[:life] } || pool.max_by { |one| one[:age] / one[:life] }

  def splash(x, y, color)
    dot = free(@dots)
    dot.merge!(kind: :splash, age: 0.0, life: 0.9, x: x, y: y, vx: rand(-130.0..130.0), vy: rand(-330.0..-170.0), size: rand(6.0..11.0), floor: y, color: color)
  end

  # With paint in the bowl the trail is that colour; with none, it runs through the rainbow.
  def trail(x, y)
    color = @level > 0.01 ? @shown : Paint.mix(COLOURS.values[(@t * 3).to_i % 12][0])
    free(@dots).merge!(kind: :bubble, age: 0.0, life: 1.0, x: x + rand(-6.0..6.0), y: y + rand(-6.0..6.0),
      vx: rand(-12.0..12.0), vy: -40.0, size: rand(10.0..18.0), color: Paint.lighten(color, 0.3))
  end

  def sparkle(x, y, angle = rand * 2 * Math::PI, color = nil)
    star = free(@stars)
    color ||= [[255, 214, 90], [255, 170, 200], [150, 210, 255], [170, 235, 170]].sample
    speed = rand(70.0..140.0)
    star.merge!(age: 0.0, life: 0.8, x: x, y: y, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed - 30, color: color, turn: rand(-200.0..200.0))
  end

  def move_bits(dt)
    @dots.each do |dot|
      next if dot[:age] >= dot[:life]

      dot[:age] += dt
      dot[:x] += dot[:vx] * dt
      dot[:y] += dot[:vy] * dt
      if dot[:kind] == :splash
        dot[:vy] += 1100 * dt
        dot[:age] = dot[:life] if dot[:vy] > 0 && dot[:y] > surface_y
      end
      fade = 1 - dot[:age] / dot[:life]
      size = dot[:size] * (dot[:kind] == :bubble ? 0.5 + 0.5 * fade : 1)
      bubble = dot[:kind] == :bubble
      dot[:art].style(left: dot[:x].round(1), top: dot[:y].round(1), width: size.round(1), height: size.round(1), hidden: dot[:age] >= dot[:life],
        fill: paint(dot[:color], bubble ? 0.45 * fade : 1), stroke: bubble ? paint(Paint.darken(dot[:color], 0.3), 0.7 * fade) : paint(dot[:color], 0))
    end
    @stars.each do |star|
      next if star[:age] >= star[:life]

      star[:age] += dt
      star[:x] += star[:vx] * dt
      star[:y] += star[:vy] * dt
      star[:vx] *= 0.94
      star[:vy] *= 0.94
      k = star[:age] / star[:life]
      size = 14 * Math.sin(Math::PI * [k, 1].min)
      star[:art].style(left: star[:x].round(1), top: star[:y].round(1), outer: size.round(1), inner: (size * 0.45).round(1),
        rotate: (star[:turn] * star[:age]).round(1), fill: paint(star[:color]), hidden: k >= 1)
    end
  end

  def bounce(dt)
    POTS.each do |pot|
      next if pot[:spring].still? && pot[:spring].at.zero? && !pot[:moved]

      offset = pot[:spring].step(dt)
      pot[:moved] = !pot[:spring].still?
      pot[:slot].move(pot[:x] - 65, (POT_Y + offset).round(1))
      pot[:shadow].style(width: 118 + offset * 1.2)
    end
    @jars.each_value do |jar|
      next if jar[:spring].still? && jar[:spring].at.zero? && !jar[:moved]

      offset = jar[:spring].step(dt)
      jar[:moved] = !jar[:spring].still?
      jar[:slot].move(jar[:x] - 16, (SHELF_Y - 46 + offset).round(1))
    end
    @chip.move(BOWL_X - 170, (132 + @chip_spring.step(dt) * 0.25).round(1)) unless @chip_spring.still? && !@chip_moving
    @chip_moving = !@chip_spring.still?
    lizard = @lizard[:spring]
    @lizard[:slot].move(LIZARD_X, (LIZARD_Y + lizard.step(dt) * 0.15).round(1)) unless lizard.still? && !@lizard_moving
    @lizard_moving = !lizard.still?
  end

  # The chameleon watches the drops (or your pointer), blinks, and matches the paint.
  def watch(dt)
    lizard = @lizard
    target = @drops_flying.last ? [@drops_flying.last[:body].left, @drops_flying.last[:body].top] : @pointer
    look = target ? [target[0] - LIZARD_X - 96, target[1] - LIZARD_Y - 68] : [-60, 40]
    length = Math.hypot(*look)
    look = look.map { |v| v / length * 3.2 } if length > 0
    lizard[:look] = Paint.blend(lizard[:look], look, 1 - Math.exp(-dt * 12))
    at = lizard[:look].map { |v| v.round(1) }
    lizard[:pupil].style(left: 96 + at[0], top: 68 + at[1]) unless at == lizard[:pupil_at]
    lizard[:pupil_at] = at

    if @t >= lizard[:blink_at]
      lizard[:lid].show
      lizard[:blink_at] = @t + rand(2.5..5.5)
      lizard[:open_at] = @t + 0.13
    end
    if lizard[:open_at] && @t >= lizard[:open_at]
      lizard[:lid].hide
      lizard[:open_at] = nil
    end

    color = @level > 0.01 ? @shown : [108, 192, 112]
    if @rainbow_skin
      @rainbow_skin += dt / 1.6
      hue = COLOURS.values.first(12).map { |drops, _| Paint.mix(drops) }
      at = @rainbow_skin * hue.size
      color = Paint.blend(hue[at.floor % hue.size], hue[(at.floor + 1) % hue.size], at % 1)
      @rainbow_skin = nil if @rainbow_skin >= 1
    end
    @lizard_color = Paint.around(@lizard_color, color, 1 - Math.exp(-dt * 4))
    @lizard_frame = !@lizard_frame # recolouring every other frame is plenty for the eye
    if @lizard_frame && @lizard_color.zip(@painted_lizard).any? { |now, was| (now - was).abs > 1.5 }
      paint_lizard(@lizard_color)
      @painted_lizard = @lizard_color
    end

    tongue = lizard[:tongue_age]
    return unless tongue

    lizard[:tongue_age] += dt / 0.5
    reach = 58 * Math.sin(Math::PI * [lizard[:tongue_age], 1].min)
    x2, y2 = 68 - reach, 92 - reach * 0.35
    lizard[:tongue].style(x2: x2, y2: y2, hidden: false)
    lizard[:tip].style(left: x2, top: y2, hidden: false)
    return unless lizard[:tongue_age] >= 1

    lizard[:tongue_age] = nil
    lizard[:tongue].hide
    lizard[:tip].hide
  end

  # When nobody has done anything for a while, the pots hop one after another to say hello.
  def invite
    return if @t - @busy_at < 6

    @busy_at = @t
    POTS.each_with_index { |pot, i| timer(0.18 * i) { pot[:spring].kick(-150) } }
  end

  # ---- the sound switch, and the way out for grown-ups ----

  def toggle_sound
    @chimes.muted = !@chimes.muted
    @waves.each { |wave| wave.hidden = @chimes.muted }
    @hush.each { |line| line.hidden = !@chimes.muted }
    @chimes.tune("c5 g5", gap: 0.1, level: 0.6) unless @chimes.muted
  end

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

  # ---- remembering the shelf ----

  def load_shelf
    found = JSON.parse(File.read(SAVE_FILE))["found"]
    found.is_a?(Array) ? found & COLOURS.keys : []
  rescue JSON::ParserError, SystemCallError, TypeError, NoMethodError
    []
  end

  def save_shelf
    FileUtils.mkdir_p(File.dirname(SAVE_FILE))
    File.write(SAVE_FILE, JSON.pretty_generate("found" => @found))
  rescue SystemCallError
    # somewhere read-only: the shelf is full for today, and starts fresh next time
  end

  # ---- taps and keys ----

  def tap_jar(name)
    @busy_at = @t
    @jars[name][:spring].kick(-200)
    drops = COLOURS[name][0]
    if @found.include?(name)
      @name = name
      show_name(name, drops)
      @chimes.tune(COLOURS[name][1])
    else
      show_recipe(drops)
      @chip.hide
      @chimes.tune("e5 c5", voice: :hum, gap: 0.22, level: 0.6)
    end
    @recipe_until = @t + 4
  end

  def sing_again
    return tickle unless @name

    show_name(@name, @drops.sum.zero? ? COLOURS[@name][0] : @drops)
    @chimes.tune(COLOURS[@name][1])
  end

  def key(key)
    @busy_at = @t
    return hold_escape if key == :escape

    @escape_from = nil
    pot = POTS.find { |one| one[:keys].include?(key.to_s.downcase) }
    case key
    when " " then stir
    when :backspace, :delete then empty_bowl
    when "\n", :enter, :return then sing_again
    else pour(pot || POTS.sample)
    end
  end

  # ---- building it ----

  @t = 0.0
  @busy_at = 0.0
  @last_pour = -1.0
  @found = load_shelf
  @chimes = Chimes.new
  @drops = [0, 0, 0, 0]
  @drops_flying = []
  @recipe_shown = []
  @level = @level_goal = 0.0
  @shown = @target = Paint::WHITE
  @swirl_color = Paint::WHITE
  @swirl_strength = 0.0
  @spin = 0.0
  @spin_speed = 1.2
  @lizard_color = [108, 192, 112]

  room
  title_colors = [[229, 57, 53], [255, 138, 30], [236, 176, 20], [67, 178, 88], [47, 128, 237], [142, 76, 196]]
  letters = "Rainbow Lab".chars.each_with_index.map { |letter, i| span(letter, stroke: paint(title_colors[i % 6])) }
  para(*letters, font: "Fredoka", size: 24, weight: 600, left: 36, top: 10)
  @rainbow = stack(left: 0, top: 0, width: W, height: COUNTER_Y, hidden: @found.size < COLOURS.size) { rainbow_art }
  shelf
  name_card
  bowl_back
  paint_layer
  bowl_front
  chameleon
  pots
  buttons
  @flight_layer = stack(left: 0, top: 0, width: W, height: H) {}
  @dots = Array.new(28) { { art: oval(0, 0, 8, center: true, strokewidth: 2, hidden: true), age: 1.0, life: 1.0 } }
  transform :center # sparkles turn about their own middles
  @stars = Array.new(18) { { art: star(0, 0, 5, 10, 4.5, hidden: true), age: 1.0, life: 1.0 } }
  @jar_layer = stack(left: 0, top: 0, width: W, height: H) {}
  @hint = para "hold esc to leave", size: 10, stroke: paint(INK, 0.45), left: 36, top: 698
  nofill
  @leaving = arc 14, 698, 14, 14, -Math::PI / 2, -Math::PI / 2, stroke: paint(INK, 0.6), strokewidth: 3, hidden: true

  click do |_button, x, y|
    @busy_at = @t
    if on_lizard?(x, y)
      nil # it has its own tickle
    elsif (x - BOWL_X)**2 / BOWL_RX.to_f**2 + (y - RIM_Y)**2 / BOWL_RY.to_f**2 <= 1 && y > RIM_Y - RIM_RY
      stir
    elsif y > 130 && !on_button?(x, y) && !POTS.any? { |pot| (x - pot[:x]).abs < 66 && y > POT_Y }
      5.times { sparkle(x, y) }
      @chimes.tune(%w[c5 d5 e5 g5 a5 c6].sample, level: 0.35)
    end
  end

  motion do |x, y|
    @pointer = [x, y]
    moved = @last_trail ? Math.hypot(x - @last_trail[0], y - @last_trail[1]) : 99
    if moved > 26
      trail(x, y)
      @last_trail = [x, y]
      stir_gently if (x - BOWL_X).abs < BOWL_RX * 0.8 && y.between?(RIM_Y - 40, RIM_Y + BOWL_RY)
    end
  end

  keypress { |key| key(key) }

  animate(60) do
    dt = 1 / 60.0
    @t += dt
    fly_drops(dt)
    move_paint(dt)
    fly_jar(dt)
    grow_rainbow(dt)
    bounce(dt)
    move_bits(dt)
    watch(dt)
    announce if @announce_at && @t >= @announce_at
    invite
    watch_escape
    if @recipe_until && @t > @recipe_until
      @recipe_until = nil
      @name ? show_recipe(@drops) : hide_recipe
    end
  end
end
