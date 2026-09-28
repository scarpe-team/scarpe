# Memory Match: find the pairs, and each pair of animals does a little dance
# (ages 4 and up).
#
# Eight animals live under the cards: a cat, a dog, a fish, an owl, a frog, a
# bunny, a bear and a duck, every one of them drawn from ovals and curves. Turn
# two cards over. If they match, the animals dance and sing; if not, they turn
# back over, and you try again. There is no clock and no way to lose.
#
# Three boards: Tiny (two pairs, and a peek at the start), Middle (six pairs)
# and Big (all eight). Big kid mode counts your moves, gives up to three stars,
# and remembers your best. The speaker in the corner turns the sound off.
#
# The animal voices come from a tiny synthesizer in plain Ruby: each one is
# worked out once as a WAV file and played with afplay.

require "json"
require "fileutils"
require "tmpdir"

SAVE_FILE = File.join(Dir.home, "Library", "Application Support", "Memory Match", "progress.json")

# Fredoka, the round friendly font, travels with the app. If it has gone
# missing, the Mac's own rounded font stands in.
FONT_FILE = [
  File.join(__dir__, "Fredoka.ttf"),
  File.join(__dir__, "fonts", "Fredoka.ttf"),
  File.join(__dir__, "_fonts", "Fredoka.ttf"),
  File.join(__dir__, "..", "_fonts", "Fredoka.ttf"),
].find { |path| File.exist?(path) }
FONT = FONT_FILE ? "Fredoka" : "Arial Rounded MT Bold"

W, H = 960, 720
ANIMALS = %i[cat dog fish owl frog bunny bear duck]
# Each animal's card has its own soft colour behind it (the animals tell
# themselves apart by their shapes, so colour is never the only clue).
BACKDROPS = {
  cat: [255, 225, 196], dog: [240, 226, 210], fish: [208, 240, 255], owl: [234, 226, 255],
  frog: [214, 245, 206], bunny: [255, 222, 236], bear: [246, 230, 210], duck: [255, 244, 190],
}
LEVELS = [
  { name: "Tiny", cols: 2, rows: 2, card: 190, gap: 28, peek: true },
  { name: "Middle", cols: 4, rows: 3, card: 158, gap: 22, peek: false },
  { name: "Big", cols: 4, rows: 4, card: 134, gap: 16, peek: false },
]
INK = [74, 59, 82]
WHITE = [255, 255, 255]
GOLD = [255, 190, 40]
CONFETTI = [[255, 94, 98], [255, 152, 48], [247, 190, 22], [46, 196, 112], [22, 184, 172], [64, 146, 255],
  [146, 104, 250], [255, 100, 176]]
FLIP = 0.32 # seconds for a card to turn over
WIN_FROM, WIN_AT = 12, 150 # where the win card drops in from, and where it lands

# A small synthesizer. Every sound is worked out once, written to a WAV file,
# and played in the background with afplay while the game carries on.
class Voices
  RATE = 22_050
  TAU = 2 * Math::PI
  LEVEL = 0.25 # no sound ever goes above a quarter of full volume

  attr_reader :last_file, :player
  attr_accessor :muted

  def initialize
    @dir = Dir.mktmpdir("memory-match")
    at_exit { FileUtils.rm_rf(@dir) } # the notes are only kept while the app runs
    @files = {}
    @noise = Random.new(4)
    @muted = false
  end

  def play(name)
    return if @muted

    @last_file = @files[name] ||= write(name, samples(name))
    @player = Process.detach(spawn("afplay", @last_file, out: File::NULL, err: File::NULL))
  rescue SystemCallError
    # no afplay here (not a Mac): the animals dance in silence
  end

  # A sound's samples, gently scaled. Every animal comes out about as loud
  # as the others (a frog's buzz is spikier than an owl's hoot, so each is
  # measured while it sounds), and nothing goes far past 1, so a voice stays
  # round instead of turning into a buzz.
  def samples(name)
    raw = recipe(name)
    peak = raw.map(&:abs).max.to_f
    sounding = raw.select { |sample| sample.abs > 0.02 }
    loudness = Math.sqrt(sounding.sum { |sample| sample * sample } / [sounding.size, 1].max)
    scale = ANIMALS.include?(name) ? [0.3 / loudness, 1.2 / peak].min : [0.9 / peak, 1.0].min
    raw.map { |sample| sample * scale }
  end

  def recipe(name)
    case name
    when :cat then voice(0.55, ->(k) { 600 + 260 * Math.sin(Math::PI * k**0.7) - 80 * k }, ->(k) { 900 + 800 * Math.sin(Math::PI * k) })
    when :dog then bark + rest(0.07) + bark(0.9)
    when :fish then [bubble(380), rest(0.05), bubble(460), rest(0.05), bubble(560)].flatten
    when :owl then hoot(0.3) + rest(0.12) + hoot(0.45)
    when :frog then croak(0.1) + rest(0.05) + croak(0.16)
    when :bunny then boing(0.2) + rest(0.04) + boing(0.24, 1.2)
    when :bear then voice(0.32, ->(k) { 180 + 30 * k }, ->(_) { 300 }, harmonics: 4, width: 260) + rest(0.03) +
      voice(0.42, ->(k) { 205 - 55 * k }, ->(_) { 300 }, harmonics: 4, width: 260)
    when :duck then quack + rest(0.06) + quack(0.9)
    when :flip then flick
    when :oops then tone(659, 0.16) + tone(523, 0.26)
    when :match then tone(784, 0.12, 0.6) + tone(1047, 0.35, 0.6)
    when :hooray then [523, 659, 784, 1047].flat_map { |hz| tone(hz, 0.13) } + tone(1319, 0.7)
    when :deal then Array.new(6) { flick(0.5) + rest(0.03) }.flatten
    else rest(0.1)
    end
  end

  private

  # A voice: a pitch that moves over time, shaped by a mouth (the loudest
  # overtone) that moves too. pitch and mouth take k, from 0 to 1 over the sound.
  def voice(seconds, pitch, mouth, harmonics: 10, width: 420)
    phase = 0.0
    sound(seconds) do |t, k|
      hz = pitch.call(k)
      phase += hz / RATE
      open = mouth.call(k)
      buzz = (1..harmonics).sum { |h| Math.exp(-((h * hz - open) / width)**2) * Math.sin(TAU * h * phase) }
      0.9 * buzz * [t * 40, 1, (seconds - t) * 12].min
    end
  end

  def bark(high = 1.0)
    voice(0.14, ->(k) { (430 - 170 * k) * high }, ->(k) { 950 - 300 * k }, harmonics: 12).map { |s| s + 0.03 * noise }
  end

  def quack(high = 1.0)
    voice(0.17, ->(k) { (330 - 90 * k) * high }, ->(_) { 1300 }, harmonics: 16, width: 380)
  end

  # A soft, round hoot that wavers a little.
  def hoot(seconds)
    phase = 0.0
    sound(seconds) do |t, k|
      phase += (410 - 30 * k) * (1 + 0.015 * Math.sin(TAU * 5 * t)) / RATE
      (Math.sin(TAU * phase) + 0.2 * Math.sin(TAU * 2 * phase)) * [t * 25, 1, (seconds - t) * 10].min * 0.8
    end
  end

  # A frog's croak is a low buzz that trembles quickly.
  def croak(seconds)
    voice(seconds, ->(k) { 190 - 30 * k }, ->(_) { 640 }, harmonics: 7, width: 420).each_with_index.map do |s, i|
      s * (0.75 + 0.25 * Math.sin(TAU * 32 * i / RATE))
    end
  end

  # A bubble: a quick little whistle that rises.
  def bubble(hz)
    phase = 0.0
    sound(0.07) do |_t, k|
      phase += hz * (1 + 1.4 * k) / RATE
      Math.sin(TAU * phase) * Math.sin(Math::PI * k) * 0.8
    end
  end

  def boing(seconds, high = 1.0)
    phase = 0.0
    sound(seconds) do |t, k|
      phase += (280 + 520 * k**0.6) * high * (1 + 0.04 * Math.sin(TAU * 18 * t)) / RATE
      Math.sin(TAU * phase) * [t * 60, 1].min * (1 - k) * 0.8
    end
  end

  # A card turning: a soft brush of air and a tiny tap.
  def flick(loud = 1.0)
    last = 0.0
    sound(0.06) do |t, _k|
      now = noise
      bright, last = now - last, now
      loud * (0.25 * bright * Math.exp(-t * 90) + 0.3 * Math.sin(TAU * 1400 * t) * Math.exp(-t * 120))
    end
  end

  # A music-box note.
  def tone(hz, seconds, loud = 0.8)
    sound(seconds + 0.25) do |t, _k|
      loud * [t * 90, 1].min * (Math.sin(TAU * hz * t) + 0.25 * Math.sin(TAU * 2 * hz * t) * Math.exp(-t * 6)) *
        Math.exp(-t * 5)
    end
  end

  def rest(seconds)
    Array.new((RATE * seconds).round, 0.0)
  end

  def noise
    @noise.rand * 2 - 1
  end

  # `seconds` of sound: the block gets each moment t and how far through it is, k.
  def sound(seconds)
    count = (RATE * seconds).round
    Array.new(count) { |i| yield(i.fdiv(RATE), i.fdiv(count)) }
  end

  # A WAV file is a 44-byte header, then every sample as a 16-bit number.
  # tanh rounds off the loudest moments instead of clipping them.
  def write(name, samples)
    data = samples.map { |sample| (Math.tanh(sample) * LEVEL * 32_767).round }.pack("s<*")
    header = ["RIFF", 36 + data.bytesize, "WAVE", "fmt ", 16, 1, 1, RATE, RATE * 2, 2, 16, "data", data.bytesize]
    path = File.join(@dir, "#{name}.wav")
    File.binwrite(path, header.pack("a4Va4a4VvvVVvva4V") + data)
    path
  end
end

# One card on the table. `side` is what shows (:back or :face); `turn` is a
# flip in progress, `dance` a happy dance, `hop` the jump at the very end.
Card = Struct.new(:animal, :slot, :size, :home, :at, :side, :state, :turn, :dance, :deal, :hop, :shake, :hover,
  keyword_init: true)

Shoes.app(title: "Memory Match", width: W, height: H, resizable: false) do
  # ---- remembering ----

  def load_progress
    saved = JSON.parse(File.read(SAVE_FILE)) if File.exist?(SAVE_FILE)
    saved.is_a?(Hash) ? saved : {}
  rescue JSON::ParserError, SystemCallError
    {}
  end

  def save_progress
    FileUtils.mkdir_p(File.dirname(SAVE_FILE))
    File.write(SAVE_FILE, JSON.pretty_generate(@progress.merge("muted" => @voices.muted, "big_kid" => @big_kid)))
  rescue SystemCallError
    # somewhere read-only: the game goes on, it just won't remember
  end

  # ---- colours and easing ----

  # A colour, see-through by alpha (0.0 to 1.0). Shoes reads a whole number
  # as out of 255, so alpha always goes in as a fraction.
  def tint(color, alpha = 1.0)
    rgb(*color, alpha.to_f.clamp(0.0, 1.0).round(3))
  end

  def darker(color, amount)
    color.map { |part| (part * (1 - amount)).round }
  end

  # Slows down at the end and goes a touch too far, then settles.
  def overshoot(t)
    t = t.clamp(0.0, 1.0)
    1 + 2.7 * (t - 1)**3 + 1.7 * (t - 1)**2
  end

  def smooth(t)
    t = t.clamp(0.0, 1.0)
    t * t * (3 - 2 * t)
  end

  # ---- drawing an animal ----
  #
  # Every animal is drawn on a 100 by 100 grid. These turn a grid point into
  # a spot on the card: @cx and @cy are the middle, @k is pixels per grid
  # step, and @sx and @sy squeeze the drawing while a card turns or an
  # animal dances.

  def gx(x) = (@cx + (x - 50) * @k * @sx).round(1)
  def gy(y) = (@cy + (y - 50) * @k * @sy).round(1)

  def outline_pen(line)
    if line
      stroke tint(INK)
      strokewidth (@k * 2.2).round(1)
    else
      nostroke
    end
  end

  # An oval around a grid point, w by h grid steps.
  def blob(x, y, w, h, color, line: true)
    outline_pen(line)
    fill tint(color)
    oval gx(x), gy(y), (w * @k * @sx).round(1), (h * @k * @sy).round(1), center: true
  end

  # A filled shape through grid points: [x, y] is a straight line to there,
  # and [x1, y1, x2, y2, x, y] is a curve.
  def patch(color, start, *steps, line: true)
    outline_pen(line)
    fill tint(color)
    shape do
      move_to gx(start[0]), gy(start[1])
      steps.each { |step| step.size == 2 ? line_to(gx(step[0]), gy(step[1])) : curve_to(*step.each_slice(2).flat_map { |x, y| [gx(x), gy(y)] }) }
      line_to gx(start[0]), gy(start[1])
    end
  end

  # A line drawn with a pen, through grid points the same way.
  def pen(color, width, start, *steps)
    nofill
    stroke tint(color)
    strokewidth (width * @k).round(1)
    cap :curve
    shape do
      move_to gx(start[0]), gy(start[1])
      steps.each { |step| step.size == 2 ? line_to(gx(step[0]), gy(step[1])) : curve_to(*step.each_slice(2).flat_map { |x, y| [gx(x), gy(y)] }) }
    end
  end

  def eye(x, y, w = 9, h = 11)
    blob(x, y, w, h, INK, line: false)
    blob(x + w * 0.22, y - h * 0.24, w * 0.36, w * 0.36, WHITE, line: false)
  end

  def cheeks(left, right, y)
    [left, right].each { |x| blob(x, y, 10, 6, [255, 138, 160], line: false) }
  end

  def cat
    orange, stripe, pink = [255, 176, 92], [228, 128, 44], [255, 158, 180]
    patch(orange, [19, 46], [25, 9], [47, 27])
    patch(orange, [81, 46], [75, 9], [53, 27])
    patch(pink, [26, 38], [29, 18], [41, 29], line: false)
    patch(pink, [74, 38], [71, 18], [59, 29], line: false)
    blob(50, 57, 72, 60, orange)
    pen(stripe, 3.4, [44, 31], [46, 38])
    pen(stripe, 3.4, [50, 29], [50, 37])
    pen(stripe, 3.4, [56, 31], [54, 38])
    blob(43, 69, 17, 13, WHITE, line: false)
    blob(57, 69, 17, 13, WHITE, line: false)
    patch(pink, [45, 63], [55, 63], [50, 68], line: false)
    eye(37, 53)
    eye(63, 53)
    cheeks(28, 72, 64)
    [[31, 67, 14, 63], [31, 71, 16, 73], [69, 67, 86, 63], [69, 71, 84, 73]].each do |x1, y1, x2, y2|
      pen(INK, 1.2, [x1, y1], [x2, y2])
    end
  end

  def dog
    tan, brown, cream = [230, 177, 122], [139, 90, 60], [255, 243, 224]
    blob(50, 55, 64, 60, tan)
    patch(brown, [31, 30], [15, 28, 8, 52, 15, 68], [22, 78, 34, 64, 35, 48], [35, 40, 35, 33, 31, 30])
    patch(brown, [69, 30], [85, 28, 92, 52, 85, 68], [78, 78, 66, 64, 65, 48], [65, 40, 65, 33, 69, 30])
    blob(62, 48, 19, 17, [205, 146, 92], line: false)
    blob(50, 69, 34, 26, cream)
    blob(50, 75, 8, 9, [255, 127, 158])
    blob(50, 62, 13, 9, INK, line: false)
    blob(47, 60, 4, 2.4, WHITE, line: false)
    pen(INK, 1.8, [50, 66], [49, 71, 45, 72, 42, 69])
    pen(INK, 1.8, [50, 66], [51, 71, 55, 72, 58, 69])
    eye(38, 47)
    eye(62, 47)
    cheeks(28, 72, 60)
  end

  def fish
    blue, deep, belly = [96, 200, 250], [52, 150, 220], [208, 242, 255]
    patch(deep, [32, 52], [10, 32], [17, 52], [10, 72])
    patch(deep, [44, 31], [52, 15, 66, 18, 70, 33])
    blob(55, 52, 64, 46, blue)
    blob(59, 62, 42, 18, belly, line: false)
    pen(deep, 2.4, [41, 38], [46, 46, 46, 58, 41, 66])
    blob(71, 46, 17, 17, WHITE)
    eye(72, 47, 9, 10)
    pen(INK, 1.8, [79, 58], [81, 61, 85, 61, 87, 57])
    nofill
    stroke tint(WHITE, 0.9)
    strokewidth (@k * 1.6).round(1)
    oval gx(88), gy(30), (7 * @k * @sx).round(1), (7 * @k * @sy).round(1), center: true
    oval gx(92), gy(19), (5 * @k * @sx).round(1), (5 * @k * @sy).round(1), center: true
  end

  def owl
    purple, deep, belly, orange = [160, 128, 218], [118, 90, 178], [238, 231, 252], [255, 166, 72]
    patch(deep, [27, 36], [29, 11], [45, 26])
    patch(deep, [73, 36], [71, 11], [55, 26])
    blob(21, 64, 17, 36, deep)
    blob(79, 64, 17, 36, deep)
    blob(50, 57, 64, 72, purple)
    blob(50, 73, 38, 30, belly, line: false)
    [[44, 67], [56, 67], [50, 75]].each { |x, y| pen(deep, 1.5, [x - 3, y], [x, y + 3], [x + 3, y]) }
    blob(38, 44, 25, 25, WHITE)
    blob(62, 44, 25, 25, WHITE)
    eye(38, 45, 11, 12)
    eye(62, 45, 11, 12)
    patch(orange, [45, 54], [55, 54], [50, 62])
    blob(42, 92, 11, 6, orange)
    blob(58, 92, 11, 6, orange)
  end

  def frog
    green, deep = [112, 210, 112], [70, 168, 82]
    blob(33, 33, 29, 29, green)
    blob(67, 33, 29, 29, green)
    blob(50, 61, 82, 56, green)
    blob(33, 32, 19, 19, WHITE, line: false)
    blob(67, 32, 19, 19, WHITE, line: false)
    eye(33, 33, 9, 10)
    eye(67, 33, 9, 10)
    blob(46, 52, 3, 2.4, INK, line: false)
    blob(54, 52, 3, 2.4, INK, line: false)
    pen(INK, 2.4, [28, 62], [38, 75, 62, 75, 72, 62])
    cheeks(24, 76, 65)
    [[70, 76, 7, 5], [30, 78, 5, 4], [62, 44, 4, 3]].each { |x, y, w, h| blob(x, y, w, h, deep, line: false) }
  end

  def bunny
    fur, inner, pink = [250, 246, 253], [255, 190, 210], [255, 146, 176]
    blob(37, 25, 17, 48, fur)
    blob(63, 25, 17, 48, fur)
    blob(37, 27, 8, 34, inner, line: false)
    blob(63, 27, 8, 34, inner, line: false)
    blob(50, 63, 62, 54, fur)
    eye(40, 59, 8, 10)
    eye(60, 59, 8, 10)
    patch(pink, [46, 66], [54, 66], [50, 70], line: false)
    pen(INK, 1.4, [50, 70], [50, 73])
    pen(INK, 1.4, [50, 73], [48, 76, 45, 76, 44, 74])
    pen(INK, 1.4, [50, 73], [52, 76, 55, 76, 56, 74])
    outline_pen(true)
    strokewidth (@k * 1.2).round(1)
    fill tint(WHITE)
    rect gx(47.5), gy(76), (5 * @k * @sx).round(1), (5 * @k * @sy).round(1), curve: (@k * 1.2).round(1)
    cheeks(33, 67, 68)
    [[31, 68, 17, 65], [31, 71, 18, 74], [69, 68, 83, 65], [69, 71, 82, 74]].each do |x1, y1, x2, y2|
      pen([150, 140, 160], 1.1, [x1, y1], [x2, y2])
    end
  end

  def bear
    brown, light = [180, 126, 86], [236, 206, 170]
    blob(27, 32, 23, 23, brown)
    blob(73, 32, 23, 23, brown)
    blob(27, 32, 11, 11, light, line: false)
    blob(73, 32, 11, 11, light, line: false)
    blob(50, 57, 68, 62, brown)
    blob(50, 68, 31, 23, light)
    blob(50, 62, 13, 9, INK, line: false)
    blob(47, 60, 4, 2.4, WHITE, line: false)
    pen(INK, 1.8, [50, 66], [50, 70])
    pen(INK, 1.8, [50, 70], [48, 73, 44, 73, 42, 71])
    pen(INK, 1.8, [50, 70], [52, 73, 56, 73, 58, 71])
    eye(38, 50)
    eye(62, 50)
    cheeks(28, 72, 62)
  end

  def duck
    yellow, orange, crease = [255, 216, 77], [255, 154, 60], [214, 110, 30]
    blob(50, 90, 58, 22, yellow)
    patch(yellow, [44, 27], [42, 14, 50, 11, 51, 19], [53, 12, 61, 14, 57, 27])
    blob(50, 51, 62, 60, yellow)
    blob(50, 66, 38, 17, orange)
    pen(crease, 1.8, [35, 66], [44, 68, 56, 68, 65, 66])
    eye(40, 48)
    eye(60, 48)
    cheeks(29, 71, 58)
  end

  # Draws an animal centred at (x, y), `size` pixels across, squeezed by sx and sy.
  def animal(kind, x, y, size, sx: 1.0, sy: 1.0)
    @cx, @cy, @k, @sx, @sy = x, y, size / 100.0, sx, sy
    send(kind)
  end

  # ---- a card ----

  # Draws a card from scratch: its shadow, and the back or the face. While
  # it is dealt it grows up out of its place; while it turns it is squeezed
  # from the sides, and it lifts a little.
  def paint(card)
    s = card.size * (card.deal ? pop(card.deal) : 1.0)
    o = (card.size - s) / 2.0 # the card stays centred in its place as it grows
    squeeze, lift = 1.0, 0.0
    if card.turn
      angle = Math::PI * smooth(card.turn[:t] / FLIP)
      squeeze = [Math.cos(angle).abs, 0.02].max
      lift = Math.sin(angle) * 10
    end
    dy, stretch_x, stretch_y = card.dance ? dance_pose(card.dance) : [0, 1, 1]
    cw = s * squeeze
    card.slot.clear do
      next if s < 2 # not dealt yet

      nostroke
      rect o + (s - cw) / 2 + 2, o + 6 + lift * 0.4, [cw - 4, 1].max, s - 2, curve: 18,
        fill: rgb(60, 40, 90, 0.16 + lift * 0.004)
      top = o - lift
      if card.side == :back
        card_back(s, cw, o, top, card)
      else
        card_face(card, s, cw, o, top, squeeze, dy, stretch_x, stretch_y)
      end
    end
  end

  # How big a card is while it is dealt: nothing, then up past full size and back.
  def pop(t)
    t < 0 ? 0.0 : overshoot(t / 0.4)
  end

  def card_back(s, cw, o, top, card)
    left = o + (s - cw) / 2
    fill card.hover ? "#8b7dff".."#6a5cf0" : "#7c6cff".."#5a4ae0"
    rect left, top, cw, s, curve: 18
    nofill
    stroke rgb(255, 255, 255, 0.35)
    strokewidth 3
    rect left + 8 * cw / s, top + 8, [cw - 16 * cw / s, 1].max, s - 16, curve: 12
    # a paw print in the middle
    @cx, @cy, @k, @sx, @sy = o + s / 2.0, top + s / 2.0, s / 100.0, cw / s, 1.0
    blob(50, 58, 30, 24, WHITE, line: false)
    [[32, 40], [44, 32], [56, 32], [68, 40]].each { |x, y| blob(x, y, 12, 14, WHITE, line: false) }
  end

  def card_face(card, s, cw, o, top, squeeze, dy, stretch_x, stretch_y)
    left = o + (s - cw) / 2
    matched = card.state == :matched
    fill "#fffdf7".."#fff5e6"
    stroke matched ? tint(GOLD) : rgb(200, 180, 150, 0.6)
    strokewidth matched ? 4 : 2
    rect left, top, cw, s, curve: 18
    nostroke
    fill tint(BACKDROPS[card.animal])
    oval o + s / 2.0, top + s / 2.0, s * 0.8 * squeeze, s * 0.8, center: true
    animal(card.animal, o + s / 2.0, top + s * 0.52 + dy, s * 0.74, sx: squeeze * stretch_x, sy: stretch_y)
    return unless matched && squeeze > 0.9

    # a gold star in the corner: this pair is done
    fill tint(GOLD)
    stroke tint(darker(GOLD, 0.25))
    strokewidth 1.5
    transform :center
    star(o + s - 18, top + 18, 5, 11, 5.5).style(rotate: 180)
  end

  # A hop, a squash and a stretch: three little jumps in a second.
  def dance_pose(t)
    u = (t * 3) % 1
    up = Math.sin(Math::PI * u)
    dy = -up * 12 * (1 - t / 1.2)
    [dy, 1 + 0.07 * (1 - up) - 0.05 * up, 1 - 0.06 * (1 - up) + 0.07 * up]
  end

  # ---- the table ----

  def level
    LEVELS[@level]
  end

  def home_of(i)
    lv = level
    col, row = i % lv[:cols], i / lv[:cols]
    board_w = lv[:cols] * lv[:card] + (lv[:cols] - 1) * lv[:gap]
    board_h = lv[:rows] * lv[:card] + (lv[:rows] - 1) * lv[:gap]
    left = (W - board_w) / 2
    top = 96 + (H - 96 - 20 - board_h) / 2
    [left + col * (lv[:card] + lv[:gap]), top + row * (lv[:card] + lv[:gap])]
  end

  def start_level(index)
    @level = index
    @flakes.each { |flake| flake[:art].remove }
    @flakes = []
    @board.clear
    @win_layer.clear
    @win_layer.hide
    @peek_at = nil
    @peeking = false
    lv = level
    pairs = lv[:cols] * lv[:rows] / 2
    animals = ANIMALS.shuffle.first(pairs)
    deck = (animals + animals).shuffle
    @cards = deck.each_with_index.map do |kind, i|
      card = Card.new(animal: kind, size: lv[:card], home: home_of(i), side: :back, state: :down)
      card.at = card.home
      card.deal = -0.2 - (i % lv[:cols] + i / lv[:cols]) * 0.08 # a wave from the top left
      @board.append do
        card.slot = stack(left: card.home[0], top: card.home[1], width: lv[:card], height: lv[:card] + 12)
      end
      card.slot.click { tap(card) }
      card.slot.hover { hover(card, true) }
      card.slot.leave { hover(card, false) }
      paint(card)
      card
    end
    @open = []
    @moves = 0
    @found = []
    @back_at = nil
    @won = nil
    @voices.play(:deal)
    show_status
    @on_home = false
    @home.hide
    @game.show
    @peek_at = @clock + 1.2 if lv[:peek] && !@big_kid
  end

  def hover(card, over)
    card.hover = over && card.state == :down
    paint(card) if card.side == :back && !card.turn
  end

  # Cards pop up in their own places, one after another in a wave. (Flying in
  # from one spot would send a dozen cards across the same patch of table in
  # a second: a flicker. Growing in place, each spot changes just once.)
  def deal_tick(card, dt)
    card.deal += dt
    card.deal = nil if card.deal >= 0.4
    paint(card) if card.deal.nil? || card.deal >= 0
  end

  def turn(card, side)
    card.turn = { t: 0.0, to: side }
  end

  def turn_tick(card, dt)
    card.turn[:t] += dt
    card.side = card.turn[:to] if card.turn[:t] >= FLIP / 2
    card.turn = nil if card.turn[:t] >= FLIP
    paint(card)
  end

  # ---- playing ----

  # A tap turns a card over. While two that don't match are showing, the
  # other cards only give a little wiggle: the two turn back by themselves in
  # a second. (Turning them back at once on the next tap would let quick
  # little hands blink cards up and down several times a second.)
  def tap(card)
    return if card.state != :down || card.turn || card.deal || @peek_at || @won

    if @open.size == 2
      card.shake ||= 0.0 # just a wiggle: wait a moment
      return
    end

    card.state = :up
    card.hover = false
    turn(card, :face)
    @voices.play(:flip)
    @open << card
    return if @open.size < 2

    @moves += 1
    first, second = @open
    if first.animal == second.animal
      @open = []
      timer(FLIP) { found(first, second) }
    else
      @back_at = @clock + FLIP + 1.0
      timer(FLIP + 0.05) do
        next unless @open.include?(second)

        @voices.play(:oops)
        [first, second].each { |card| card.shake = 0.0 }
      end
    end
    show_status
  end

  def turn_back
    @open.each do |card|
      card.state = :down
      turn(card, :back)
    end
    @open = []
    @back_at = nil
  end

  def found(first, second)
    return unless @cards.include?(first) # a new game started while it turned

    [first, second].each do |card|
      card.state = :matched
      card.dance = 0.0
    end
    @found << first.animal
    @voices.play(first.animal)
    timer(0.55) { @voices.play(:match) }
    sparkle(first)
    sparkle(second)
    show_status
    return unless @found.size == @cards.size / 2

    @won = @clock + 1.2
  end

  # Little stars burst out of a card.
  def sparkle(card)
    cx, cy = card.at[0] + card.size / 2.0, card.at[1] + card.size / 2.0
    8.times do |i|
      angle = i * Math::PI / 4 + 0.3
      add_flake(@board, cx, cy, Math.cos(angle) * 260, Math.sin(angle) * 260 - 80, :star, GOLD, 0.9, drag: true)
    end
  end

  # ---- the top of the screen ----

  def show_status
    @pairs_row.clear do
      n = @cards.size / 2
      step = [64, 560 / n].min
      left = (W - step * n) / 2 + step / 2
      n.times do |i|
        x = left + i * step
        fill rgb(255, 255, 255, 0.75)
        stroke rgb(124, 108, 255, 0.35)
        strokewidth 2.5
        oval x, 44, step - 8, center: true
        kind = @found[i]
        animal(kind, x, 46, (step - 8) * 0.9) if kind
      end
    end
    @moves_label.replace(@big_kid ? "Moves: #{@moves}" : "")
  end

  # ---- winning ----

  def stars_earned
    return 3 unless @big_kid

    pairs = @cards.size / 2
    return 3 if @moves <= (pairs * 1.5).ceil
    return 2 if @moves <= pairs * 2 + 1

    1
  end

  def celebrate
    @won = :done
    earned = stars_earned
    key = level[:name]
    @progress["done"] = (@progress["done"] | [key]).sort
    best = @progress["best"][key]
    @progress["best"][key] = @moves if @big_kid && (best.nil? || @moves < best)
    save_progress
    @voices.play(:hooray)
    @cards.each_with_index { |card, i| card.hop = -i * 0.05 }
    @win_layer.clear { @win_box = stack(left: 0, top: WIN_FROM, width: W, height: 360) { win_card(earned, best) } }
    @win_drop = 0.0
    @win_layer.show
    confetti
  end

  def win_card(earned, best)
    left, top, w, h = (W - 460) / 2, 0, 460, 322
    nostroke
    rect left + 4, top + 10, w, h, curve: 36, fill: rgb(60, 40, 90, 0.2)
    rect left, top, w, h, curve: 36, fill: "#ffffff".."#fff4fb"
    para "You did it!", font: FONT, weight: "bold", size: 44, stroke: "#5a4ae0", align: "center",
      left: left, top: top + 26, width: w, margin: 0
    transform :center
    3.times do |i|
      x = left + w / 2 + (i - 1) * 76
      got = i < earned
      fill got ? tint(GOLD) : rgb(220, 214, 235)
      stroke got ? tint(darker(GOLD, 0.25)) : rgb(190, 182, 210)
      strokewidth 2.5
      star(x, top + 128 - (i == 1 ? 8 : 0), 5, 32, 15).style(rotate: 180)
    end
    note = @big_kid ? "#{@moves} moves" + (best && @moves < best ? ", your best yet!" : "") : "Every pair found."
    para note, font: FONT, weight: "500", size: 18, stroke: "#6d6892", align: "center", left: left, top: top + 172,
      width: w, margin: 0
    nxt = @level + 1 < LEVELS.size
    big_button(left + (nxt ? 64 : 124), top + 214, "again", "Again") { start_level(@level) }
    big_button(left + (nxt ? 196 : 256), top + 214, "home", "Home") { go_home }
    big_button(left + 328, top + 214, "next", "Next") { start_level(@level + 1) } if nxt
  end

  # ---- confetti and stars ----

  # A star or a scrap of confetti, drawn into `layer`.
  def add_flake(layer, x, y, vx, vy, kind, color, life, drag: false)
    art = nil
    layer.append do
      nostroke
      transform :center
      art = kind == :star ? star(x, y, 5, 9, 4.5, fill: tint(color)) : rect(x, y, 12, 7, fill: tint(color))
    end
    @flakes << { art: art, kind: kind, x: x, y: y, vx: vx, vy: vy, color: color, age: 0.0, life: life,
                 spin: rand(-400..400), drag: drag }
  end

  def confetti
    90.times do
      add_flake(@win_layer, rand(0.0..W.to_f), rand(-200.0..-10.0), rand(-40.0..40.0), rand(60.0..160.0),
        %i[bit bit star].sample, CONFETTI.sample, rand(3.2..4.4))
    end
  end

  def flake_tick(flake, dt)
    flake[:age] += dt
    if flake[:drag]
      flake[:vx] *= Math.exp(-dt * 4)
      flake[:vy] = flake[:vy] * Math.exp(-dt * 4) + 60 * dt
    else
      flake[:vx] = 50 * Math.sin(flake[:age] * 3 + flake[:spin])
    end
    flake[:x] += flake[:vx] * dt
    flake[:y] += flake[:vy] * dt
    alpha = [(flake[:life] - flake[:age]) / 0.6, 1.0].min
    flake[:art].style(left: flake[:x].round(1), top: flake[:y].round(1), rotate: (flake[:age] * flake[:spin]).round % 360,
      fill: tint(flake[:color], alpha))
    flake[:age] > flake[:life]
  end

  # ---- buttons with pictures on them ----

  # A round button with a picture (house, again, next, speaker) and a small
  # word under it for grown-ups. The whole thing is 72 pixels across.
  def big_button(left, top, picture, label, &action)
    button = stack(left: left, top: top, width: 72, height: 90, cursor: :hand_cursor) do
      nostroke
      fill rgb(90, 74, 224, 0.2)
      oval 36, 40, 70, center: true
      fill "#8b7dff".."#6a5cf0"
      oval 36, 36, 70, center: true
      icon(picture, 36, 36)
      para label, font: FONT, weight: "500", size: 13, stroke: "#5a4ae0", align: "center", margin: [0, 74, 0, 0]
    end
    button.click(&action) if action
    button
  end

  def icon(picture, x, y)
    stroke white
    strokewidth 4
    cap :curve
    case picture
    when "home"
      fill white
      nostroke
      shape { move_to x - 16, y - 1; line_to x, y - 15; line_to x + 16, y - 1 }
      rect x - 11, y - 3, 22, 17, curve: 3
      fill "#6a5cf0"
      rect x - 3.5, y + 4, 7, 10, curve: 2
    when "again"
      nofill
      arc x - 13, y - 13, 26, 26, -Math::PI * 0.2, Math::PI * 1.45
      fill white
      nostroke
      shape { move_to x + 7, y - 17; line_to x + 17, y - 9; line_to x + 5, y - 5 }
    when "next"
      nofill
      line x - 13, y, x + 11, y
      line x + 3, y - 9, x + 13, y
      line x + 3, y + 9, x + 13, y
    end
  end

  def sound_button(left, top)
    button = stack(left: left, top: top, width: 64, height: 64, cursor: :hand_cursor) do
      nostroke
      fill rgb(255, 255, 255, 0.85)
      oval 32, 32, 60, center: true
      fill "#4b4a7a"
      rect 17, 25, 9, 14, curve: 2
      shape { move_to 24, 26; line_to 34, 17; line_to 34, 47; line_to 24, 38 }
      nofill
      stroke "#4b4a7a"
      strokewidth 3
      cap :curve
      @sound_parts << [[arc(32, 22, 14, 20, -1.0, 1.0), arc(30, 16, 24, 32, -1.0, 1.0)], [line(40, 26, 50, 38), line(50, 26, 40, 38)]]
    end
    button.click { toggle_sound }
  end

  def toggle_sound
    @voices.muted = !@voices.muted
    show_sound
    @voices.play(:match)
    save_progress
  end

  def show_sound
    @sound_parts.each do |on, off|
      on.each { |part| part.hidden = @voices.muted }
      off.each { |part| part.hidden = !@voices.muted }
    end
  end

  # ---- the home screen ----

  def go_home
    @on_home = true
    @game.hide
    @win_layer.hide
    @home.clear { draw_home }
    @home.show
  end

  def draw_home
    para "Memory Match", font: FONT, weight: "bold", size: 56, stroke: "#5a4ae0", align: "center",
      left: 0, top: 36, width: W, margin: 0
    para "Find the pairs!", font: FONT, weight: "500", size: 22, stroke: "#8a7fc0", align: "center",
      left: 0, top: 110, width: W, margin: 0
    # the eight animals come out to say hello, and sing when you click them
    @friends = ANIMALS.each_with_index.map do |kind, i|
      friend = stack(left: 108 + i * 94, top: 154, width: 84, height: 90, cursor: :hand_cursor) do
        nostroke
        fill tint(BACKDROPS[kind])
        oval 42, 42, 80, center: true
        animal(kind, 42, 44, 72)
      end
      friend.click do
        @voices.play(kind)
        @hops[i] = 0.0
      end
      friend
    end
    @hops = {}
    @tiles = LEVELS.each_with_index.map { |lv, i| level_tile(120 + i * 250, 262, lv, i) }
    # the first board not yet finished nods, to say "try me next"
    @beckon = LEVELS.index { |lv| !@progress["done"].include?(lv[:name]) }
    # big kid mode, for older children
    switch = stack(left: (W - 380) / 2, top: 598, width: 380, height: 58, cursor: :hand_cursor) do
      background @big_kid ? "#ffe9a8" : rgb(255, 255, 255, 0.7), curve: 29
      nostroke
      fill @big_kid ? "#6a5cf0" : rgb(90, 74, 224, 0.25)
      rect 14, 13, 58, 32, curve: 16
      fill white
      oval(@big_kid ? 56 : 30, 29, 26, center: true)
      para "Big kid mode: count my moves", font: FONT, weight: "500", size: 17, stroke: "#4b4a7a",
        left: 86, top: 17, margin: 0
    end
    switch.click do
      @big_kid = !@big_kid
      save_progress
      go_home
    end
  end

  # A level to choose: its size shown as a little table of cards.
  def level_tile(left, top, lv, index)
    tile = stack(left: left, top: top, width: 220, height: 300, cursor: :hand_cursor) do
      nostroke
      rect 4, 10, 212, 280, curve: 30, fill: rgb(60, 40, 90, 0.14)
      rect 0, 0, 212, 280, curve: 30, fill: "#ffffff".."#f6f2ff"
      mini = { 2 => 50, 4 => 34 }[lv[:cols]]
      gap = 8
      grid_w = lv[:cols] * mini + (lv[:cols] - 1) * gap
      grid_h = lv[:rows] * mini + (lv[:rows] - 1) * gap
      lv[:rows].times do |r|
        lv[:cols].times do |c|
          x = (212 - grid_w) / 2 + c * (mini + gap)
          y = 30 + (160 - grid_h) / 2 + r * (mini + gap)
          fill "#7c6cff".."#5a4ae0"
          rect x, y, mini, mini, curve: 8
        end
      end
      para lv[:name], font: FONT, weight: "bold", size: 28, stroke: "#4b4a7a", align: "center",
        left: 0, top: 206, width: 212, margin: 0
      pairs = lv[:cols] * lv[:rows] / 2
      best = @progress["best"][lv[:name]]
      # big kids see their best, something to beat
      note = @big_kid && best ? "#{pairs} pairs, best #{best} moves" : "#{pairs} pairs"
      para note, font: FONT, weight: "500", size: 15, stroke: "#8a7fc0", align: "center",
        left: 0, top: 244, width: 212, margin: 0
      next unless @progress["done"].include?(lv[:name])

      # a gold star: this board has been finished before
      transform :center
      fill tint(GOLD)
      stroke tint(darker(GOLD, 0.25))
      strokewidth 2
      star(188, 22, 5, 22, 10).style(rotate: 180)
    end
    tile.click { start_level(index) }
    tile
  end

  # ---- every frame ----

  def tick
    dt = 1.0 / 60
    @clock += dt
    return home_tick if @on_home
    return unless @cards

    drop_tick if @win_drop
    @cards.each do |card|
      deal_tick(card, dt) if card.deal
      turn_tick(card, dt) if card.turn
      if card.dance
        card.dance += dt
        card.dance = nil if card.dance > 1.2
        paint(card)
      end
      hop_tick(card, dt) if card.hop
      shake_tick(card, dt) if card.shake
    end
    @flakes.reject! { |flake| flake_tick(flake, dt).tap { |gone| flake[:art].remove if gone } }
    peek_tick
    turn_back if @back_at && @clock >= @back_at
    celebrate if @won.is_a?(Float) && @clock >= @won
  end

  # On the home screen the animals bob in a slow wave, one hops when it is
  # clicked, and the next board to try nods now and then.
  def home_tick
    @friends.each_with_index do |friend, i|
      bob = Math.sin(@clock * 2.2 - i * 0.7) * 3
      if @hops[i]
        @hops[i] += 1.0 / 60
        bob -= Math.sin(Math::PI * [@hops[i] / 0.45, 1].min) * 18
        @hops.delete(i) if @hops[i] > 0.45
      end
      friend.move(108 + i * 94, (154 + bob).round(1))
    end
    return unless @beckon

    nod = @clock % 2.4 < 0.5 ? Math.sin(Math::PI * (@clock % 2.4) / 0.5) * 10 : 0
    @tiles[@beckon].move(120 + @beckon * 250, (262 - nod).round(1))
  end

  # The win card drops in and bounces to a stop. (It starts just inside the
  # window: Shoes reads a slot's negative top as "up from the bottom", so a
  # card dropping from above the window would first flash up at the bottom.)
  def drop_tick
    @win_drop += 1.0 / 60
    @win_box.move(0, (WIN_FROM + (WIN_AT - WIN_FROM) * overshoot(@win_drop / 0.6)).round(1))
    @win_drop = nil if @win_drop >= 0.6
  end

  # Not a pair: both cards give a small shake of the head.
  def shake_tick(card, dt)
    card.shake += dt
    wobble = Math.sin(card.shake * 38) * 6 * (1 - card.shake / 0.4)
    card.slot.move((card.home[0] + wobble).round(1), card.home[1])
    return if card.shake < 0.4

    card.shake = nil
    card.slot.move(*card.home)
  end

  # At the end every card jumps for joy, one after another, in waves.
  def hop_tick(card, dt)
    card.hop += dt
    t = card.hop % 1.6
    up = card.hop > 0 && t < 0.45 ? Math.sin(Math::PI * t / 0.45) * 22 : 0
    card.slot.move(card.home[0], (card.home[1] - up).round(1))
    return if card.hop <= 4.8

    card.hop = nil
    card.slot.move(*card.home)
  end

  # On the Tiny board every card shows its animal for a moment first.
  def peek_tick
    return unless @peek_at

    if @clock >= @peek_at && !@peeking
      @peeking = true
      @cards.each { |card| turn(card, :face) }
    elsif @peeking && @clock >= @peek_at + 1.8
      @cards.each { |card| turn(card, :back) }
      @peeking = false
      @peek_at = nil
    end
  end

  # ---- building it ----

  @voices = Voices.new
  @progress = load_progress
  @progress["done"] = Array(@progress["done"]).grep(String)
  @progress["best"] = @progress["best"].is_a?(Hash) ? @progress["best"] : {}
  @voices.muted = @progress.delete("muted") == true
  @big_kid = @progress.delete("big_kid") == true
  @clock = 0.0
  @flakes = []
  @sound_parts = []
  font FONT_FILE if FONT_FILE

  background "#fdf2ff".."#e6f7ff"
  # soft dots on the tablecloth
  nostroke
  dots = Random.new(8)
  26.times do
    fill tint(CONFETTI[dots.rand(CONFETTI.size)], 0.08)
    oval dots.rand(0..W), dots.rand(0..H), dots.rand(30..90), center: true
  end

  @home = stack(left: 0, top: 0, width: W, height: H) {}
  @game = stack(left: 0, top: 0, width: W, height: H, hidden: true) do
    @board = stack(left: 0, top: 0, width: W, height: H) {}
    big_button(20, 12, "home", "") { go_home }
    @pairs_row = stack(left: 0, top: 0, width: W, height: 90) {}
    @moves_label = para "", font: FONT, weight: "600", size: 18, stroke: "#5a4ae0", align: "right",
      left: W - 300, top: 34, width: 200, margin: 0
  end
  @win_layer = stack(left: 0, top: 0, width: W, height: H, hidden: true) {}
  sound_button(W - 84, 14)
  show_sound
  go_home

  animate(60) { tick }
end
