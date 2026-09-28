# Key Splash: a keyboard to bang on, for the littlest hands (ages 2 and up).
#
# Every key blooms its letter or number, huge, in a splash of colour with a
# note of its own. Numbers bring that many stars to count. Keys with no
# letter on them bloom a smiling star. A click tosses balls, stars and
# hearts that bounce down the hills, and a wiggle of the mouse leaves a
# trail of bubbles. Nothing to read and nothing to get wrong: mashing is
# the whole idea.
#
# For grown-ups, in the top corner: the speaker turns the sound off and on,
# and holding the Name button lets you type a name, so that every key then
# spells it out one letter at a time. Hold Escape for two seconds to leave.
# (Cmd-Q works too. A Shoes app cannot switch off the Mac's own shortcuts.)
#
# The notes come from a tiny synthesizer in plain Ruby: each one is worked
# out once as a WAV file and played with afplay. They all sit on a pentatonic
# scale, so any keys pressed together sound lovely.

require "json"
require "fileutils"
require "tmpdir"

SETTINGS_FILE = File.join(Dir.home, "Library", "Application Support", "Key Splash", "settings.json")

# Fredoka, the round friendly font, travels with the app. If it has gone
# missing, the Mac's own rounded font stands in.
FONT_FILE = [
  File.join(__dir__, "Fredoka.ttf"),
  File.join(__dir__, "fonts", "Fredoka.ttf"),
  File.join(__dir__, "_fonts", "Fredoka.ttf"),
  File.join(__dir__, "..", "_fonts", "Fredoka.ttf"),
].find { |path| File.exist?(path) }
FONT = FONT_FILE ? "Fredoka" : "Arial Rounded MT Bold"

# Colours as [red, green, blue]. Each paint is [bright, deep]: a letter, and its shadow.
PAINTS = [
  [[255, 94, 98], [196, 52, 70]],    # strawberry
  [[255, 152, 48], [201, 96, 18]],   # tangerine
  [[247, 190, 22], [178, 124, 8]],   # sunflower
  [[46, 196, 112], [24, 130, 74]],   # leaf
  [[22, 184, 172], [12, 120, 116]],  # sea
  [[64, 146, 255], [36, 90, 196]],   # sky
  [[146, 104, 250], [98, 62, 196]],  # violet
  [[255, 100, 176], [192, 56, 128]], # bubblegum
]
WHITE = [255, 255, 255]
INK = [74, 59, 82]
GOLD, GOLD_SHADE = [255, 190, 40], [214, 128, 20]

# The notes, lowest to highest: every one of them on the pentatonic scale.
LADDER = %w[g3 a3 c4 d4 e4 g4 a4 c5 d5 e5 g5 a5 c6 d6 e6 g6]
# The keyboard's rows, bottom to top. Along a row the notes climb, and each
# row starts a little higher than the one below, like a xylophone.
ROWS = { "zxcvbnm,./" => 0, "asdfghjkl;'" => 2, "qwertyuiop[]" => 3, "1234567890-=" => 5 }

GROW, STAY, FADE = 0.5, 1.5, 0.9 # seconds a bloom takes to grow in, to stay, and to fade away
MOST_BLOOMS = 6    # with more than this, the oldest starts fading early
MOST_BITS = 150    # balls, stars, hearts, bubbles and sparks, all together
GRAVITY = 1150     # pixels per second, per second
HOLD_TO_LEAVE = 2.0
HOLD_FOR_NAME = 1.5
DOZE = 20 # seconds with nobody playing before the sun nods off

# A tiny synthesizer. Each sound is worked out once, written to a WAV file,
# and played in the background with afplay while the app carries on.
class Chimes
  RATE = 22_050
  TAU = 2 * Math::PI
  NOTE_NAMES = %w[c c# d d# e f f# g g# a a# b]
  LEVEL = 0.25 # no sound ever goes above a quarter of full volume
  VOICES = 6   # and never more than six at once, however fast the keys come

  attr_reader :last_file, :player
  attr_accessor :muted

  def initialize
    @dir = Dir.mktmpdir("key-splash")
    at_exit { FileUtils.rm_rf(@dir) } # the notes are only kept while the app runs
    @files = {}
    @players = []
    @muted = false
  end

  # kind is :bell, :pop or :twinkle; note is a name like "c5".
  def play(kind, note)
    return if @muted

    @players.select!(&:alive?)
    return if @players.size >= VOICES

    @last_file = @files[[kind, note]] ||= write("#{kind}-#{note}", send(kind, frequency(note)))
    @player = Process.detach(spawn("afplay", @last_file, out: File::NULL, err: File::NULL))
    @players << @player
  rescue SystemCallError
    # no afplay here (not a Mac): the colours carry on without the notes
  end

  private

  # A music-box note: a pure tone with a little sparkle above it, struck
  # softly and left to ring.
  def bell(hz)
    sound(1.3) do |t|
      [t * 80, 1].min * (Math.sin(TAU * hz * t) * Math.exp(-t * 3.2) +
        0.28 * Math.sin(TAU * 2 * hz * t) * Math.exp(-t * 7) +
        0.07 * Math.sin(TAU * 3 * hz * t) * Math.exp(-t * 12))
    end
  end

  # A round little boop that slides up into its note.
  def pop(hz)
    phase = 0.0
    sound(0.4) do |t|
      phase += hz * (1 - 0.22 * Math.exp(-t * 35)) / RATE
      [t * 150, 1].min * 0.9 * Math.sin(TAU * phase) * Math.exp(-t * 8)
    end
  end

  # A quiet, high shimmer, for bubbles.
  def twinkle(hz)
    sound(0.35) do |t|
      [t * 200, 1].min * 0.4 * (Math.sin(TAU * 2 * hz * t) + 0.25 * Math.sin(TAU * 4 * hz * t)) * Math.exp(-t * 11)
    end
  end

  # `seconds` of sound, a sample for each moment t, with the last 20 ms faded out.
  def sound(seconds)
    count = (RATE * seconds).round
    Array.new(count) { |i| yield(i.fdiv(RATE)) * [(count - i) / 440.0, 1].min }
  end

  # "a4" is 440 Hz, and each semitone up is the twelfth root of two higher.
  def frequency(note)
    semitones = NOTE_NAMES.index(note[/\D+/]) + 12 * (note[/\d+/].to_i + 1) - 69
    440 * 2**(semitones / 12.0)
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

# A letter, a number or a smiling star, blooming on the sky.
Bloom = Struct.new(:what, :parts, :face, :glow, :stars, :x, :y, :size, :box, :paint, :age, :fading, :hop, keyword_init: true)
# Something small and bouncy: a ball, a star, a heart, a bubble or a spark.
Bit = Struct.new(:art, :kind, :motion, :x, :y, :vx, :vy, :size, :color, :age, :life, :spin, :squash)

Shoes.app(title: "Key Splash", width: 1000, height: 660) do
  # ---- what a grown-up chose, kept for next time ----

  def load_settings
    saved = JSON.parse(File.read(SETTINGS_FILE)) if File.exist?(SETTINGS_FILE)
    saved.is_a?(Hash) ? saved : {}
  rescue JSON::ParserError, SystemCallError
    {}
  end

  def save_settings
    FileUtils.mkdir_p(File.dirname(SETTINGS_FILE))
    File.write(SETTINGS_FILE, JSON.pretty_generate("name" => @name, "muted" => @chimes.muted))
  rescue SystemCallError
    # somewhere read-only: it just won't remember next time
  end

  # ---- colours, curves and notes ----

  # A colour, see-through by alpha (0.0 is invisible, 1.0 is solid). Shoes
  # reads a whole number as out of 255, so alpha always goes in as a fraction.
  def tint(color, alpha = 1.0)
    rgb(*color, alpha.to_f.clamp(0.0, 1.0).round(3))
  end

  # Like clamp, but a window squeezed too small to fit both limits just gets
  # the middle (clamp itself would stop the app with an error).
  def within(value, low, high)
    low > high ? (low + high) / 2.0 : value.clamp(low, high)
  end

  # The same colour, `amount` of the way to white.
  def lighter(color, amount)
    color.map { |part| (part + (255 - part) * amount).round }
  end

  # Comes up fast, goes a little past 1 and settles back: a bouncy grow.
  def springy(t)
    t = t.clamp(0.0, 1.0)
    1 + 3.2 * (t - 1)**3 + 2.2 * (t - 1)**2
  end

  def smooth(t)
    t = t.clamp(0.0, 1.0)
    t * t * (3 - 2 * t)
  end

  # The top of the front hill, where things bounce.
  def ground(x)
    height - 74 - 15 * Math.sin(x / 170.0 + 0.6) - 7 * Math.sin(x / 61.0)
  end

  def back_hill(x)
    height - 118 - 26 * Math.sin(x / 230.0 + 2.2) - 10 * Math.sin(x / 97.0)
  end

  def note_for(char)
    ROWS.each do |row, start|
      at = row.index(char.downcase)
      return LADDER[(start + at).clamp(0, LADDER.size - 1)] if at
    end
    LADDER[char.ord % LADDER.size]
  end

  # Across the window from low to high, like a piano.
  def note_across(x)
    LADDER[(3 + x / width.to_f * 10).round.clamp(0, LADDER.size - 1)]
  end

  def next_paint
    @paint_turn = (@paint_turn + 1) % PAINTS.size
    PAINTS[@paint_turn]
  end

  # ---- the world: sky, sun, clouds and hills ----

  # Two hills with room for a rainbow between them, and flowers on top.
  def draw_land
    w, h = width, height
    @far_hill.clear do
      nostroke
      fill "#bff0c9".."#94dfae"
      shape do
        move_to 0, h
        (0..w + 20).step(20) { |x| line_to x, back_hill(x) }
        line_to w + 20, h
      end
    end
    @land.clear do
      nostroke
      fill "#86dc95".."#4fbd6d"
      shape do
        move_to 0, h
        (0..w + 20).step(20) { |x| line_to x, ground(x) }
        line_to w + 20, h
      end
      # flowers along the hilltop
      [0.07, 0.24, 0.43, 0.61, 0.79, 0.94].each_with_index do |spot, i|
        x = spot * w
        y = ground(x) + 10
        stroke "#3f9d58"
        strokewidth 3
        line x, y, x, y - 18
        nostroke
        fill tint(PAINTS[(i * 3) % PAINTS.size][0])
        5.times { |petal| oval x + 7 * Math.cos(petal * 1.2566), y - 22 + 7 * Math.sin(petal * 1.2566), 10, center: true }
        fill "#fff3b0"
        oval x, y - 22, 8, center: true
      end
    end
    @land_size = [w, h]
    show_ribbon if @ribbon
  end

  # A cloud is one shape made of four puffs, so it can drift off one edge
  # and back in at the other.
  def draw_cloud(left, top, scale)
    nostroke
    fill rgb(255, 255, 255, 0.88)
    shape(left: left, top: top) do
      [[40, 44, 56], [74, 34, 64], [110, 44, 52], [76, 52, 100]].each do |x, y, d|
        oval x * scale, y * scale, d * scale, d * 0.8 * scale, center: true
      end
    end
  end

  def drift_clouds
    @clouds.each_with_index do |cloud, i|
      x = (@cloud_x[i] + 200 + @clock * (7 + i * 3)) % (width + 260) - 200
      cloud.move(x.round, cloud.top)
    end
  end

  # The sun watches whatever just happened, blinks now and then, giggles
  # when something new blooms, and dozes off when nobody is playing.
  def draw_sun
    @sun = stack(left: 20, top: 16, width: 150, height: 150) do
      nostroke
      transform :center # the rays turn about the sun's middle
      fill "#ffe07a".."#ffc85a"
      @rays = star(75, 75, 12, 70, 54)
      fill "#ffe98a".."#ffbd3d"
      oval 75, 75, 100, center: true
      fill rgb(255, 128, 110, 0.4)
      oval 47, 90, 20, 12, center: true
      oval 103, 90, 20, 12, center: true
      fill "#5b3b1c"
      @eyes = [oval(59, 68, 12, 15, center: true), oval(91, 68, 12, 15, center: true)]
      fill white
      @glints = [oval(61, 64, 4, center: true), oval(93, 64, 4, center: true)]
      nofill
      stroke "#5b3b1c"
      strokewidth 3.5
      cap :curve
      @shut = [shape { move_to 52, 69; curve_to 56, 74, 62, 74, 66, 69 },
               shape { move_to 84, 69; curve_to 88, 74, 94, 74, 98, 69 }]
      @shut.each(&:hide)
      @smile = shape { move_to 61, 90; curve_to 67, 101, 83, 101, 89, 90 }
      nostroke
      fill "#8a3b2a"
      @laugh = shape { move_to 60, 88; curve_to 64, 106, 86, 106, 90, 88 }
      @laugh.hide
    end
  end

  def giggle(x, y)
    @look_at = [x, y]
    @giggle = 0.45
  end

  # Asleep, the sun's z's drift up and away from it, one after another.
  def doze(dozing)
    unless dozing == @dozing
      @dozing = dozing
      @zeds.each { |z| z.hidden = !dozing }
    end
    return unless dozing

    @zeds.each_with_index do |z, i|
      k = (@clock * 0.4 + i / 3.0) % 1
      z.style(left: (150 + 44 * k).round(1), top: (78 - 56 * k).round(1), size: (14 + 14 * k).round(1),
        stroke: tint([96, 112, 176], 0.85 * Math.sin(Math::PI * k)))
    end
  end

  def sun_tick
    @rays.style(rotate: (@clock * 6) % 360) if @frame % 4 == 0
    # the eyes look towards the last thing that happened
    dx, dy = @look_at[0] - 95, @look_at[1] - 91
    far = [Math.hypot(dx, dy), 1].max
    look = [(dx / far * 4).round(1), (dy / far * 4).round(1)]
    unless @eyes_at == look
      @eyes_at = look
      @eyes.each_with_index { |eye, i| eye.style(left: 59 + i * 32 + look[0], top: 68 + look[1]) }
      @glints.each_with_index { |glint, i| glint.style(left: 61 + i * 32 + look[0], top: 64 + look[1]) }
    end
    dozing = @clock - @last_input > DOZE
    doze(dozing)
    blink = dozing || (@clock % 4.2) < 0.13
    unless blink == @blinking
      @blinking = blink
      (@eyes + @glints).each { |part| part.hidden = blink }
      @shut.each { |part| part.hidden = !blink }
    end
    @giggle = [@giggle - 1 / 60.0, 0].max
    laughing = @giggle > 0
    unless laughing == @laughing
      @laughing = laughing
      @laugh.hidden = !laughing
      @smile.hidden = laughing
    end
    hop = laughing ? (Math.sin(@giggle * 26).abs * 7).round(1) : 0
    @sun.move(20, 16 - hop) unless @sun_hop == hop
    @sun_hop = hop
  end

  # ---- keys ----

  def press(key)
    @last_input = @clock
    return close_card if @card && key == :escape
    return if @card

    if key == :escape
      return escape_held if holding_escape?

      @escape_since = @escape_last = @clock # this might be the start of a hold
    else
      @escape_since = nil
    end
    # :alt_a is Command-A, :shift_left is Shift and the left arrow
    name = key.is_a?(Symbol) ? key.to_s.split("_").last : key
    # a key held down repeats; let it bloom only now and then
    return if name == @last_key && @clock - @last_key_at < 0.3

    @last_key, @last_key_at = name, @clock
    return spell_next if @name

    case name
    when " " then blow_bubbles
    when "\n", "enter" then rainbow
    when "left", "right", "up", "down" then comet(name)
    when /\A\p{L}\z/
      bloom(name.upcase)
      @chimes.play(:bell, note_for(name))
    when /\A\d\z/
      bloom(name, stars: name.to_i)
      @chimes.play(:bell, note_for(name))
    else
      bloom(:star)
      @chimes.play(:bell, LADDER[rand(4..12)])
    end
  end

  # ---- blooms: the big letters ----

  # Where the next bloom goes: the part of the sky left empty longest, so
  # fast mashing spreads them out instead of piling them up in one place.
  def spot_for(size)
    cols, rows = 4, 2
    cell = @last_used.each_with_index.min_by { |used, _| [used, rand] }[1]
    @last_used[cell] = @clock
    row, col = cell.divmod(cols)
    top_space, bottom = 150, ground(width / 2.0) - 30
    cw, ch = (width - 160) / cols.to_f, (bottom - top_space) / rows.to_f
    x = 80 + cw * (col + 0.5 + rand(-0.25..0.25))
    y = top_space + ch * (row + 0.5 + rand(-0.2..0.2))
    [x, within(y, size * 0.5, bottom - size * 0.3)]
  end

  def bloom_size
    [height * 0.4, 300].min
  end

  # A letter or number, huge, or a smiling star (what is :star), with a
  # splash of colour around it. A number brings that many stars to count.
  def bloom(what, x = nil, y = nil, size: bloom_size, paint: next_paint, stars: 0)
    x, y = spot_for(size) unless x
    rows = stars > 5 ? 2 : 1
    y = [y, ground(x) - size * 0.62 - rows * size * 0.2 - 12].min if stars > 0
    # Text is placed by its left and top, and Shoes reads a negative one as
    # "from the far edge", so a bloom keeps a little way in from the edges.
    x = within(x, size * 0.56, width - size * 0.56)
    y = [y, size * 0.62 + 70].max
    box = [2 * [size, x - size * 0.05, width - x - size * 0.05].min, 20].max
    parts = face = glow = nil
    @glow_layer.append do
      nostroke
      halo = oval(x, y, 10, center: true, fill: tint(WHITE, 0))
      nofill
      ring = oval(x, y, 10, center: true, stroke: tint(paint[0], 0), strokewidth: 6)
      glow = [halo, ring]
    end
    @bloom_layer.append do
      nostroke
      transform :center
      # a shadow, a white rim, and the colour on top
      looks = [[paint[1], 0.35, 0.025, 0.04], [WHITE, 0.7, -0.012, -0.012], [paint[0], 1.0, 0, 0]]
      parts = looks.map do |color, strength, dx, dy|
        art = if what == :star
                star(x, y, 5, 2, 1, fill: tint(color, 0))
              else
                para(what, font: FONT, weight: "bold", size: 2, stroke: tint(color, 0), align: "center", margin: 0,
                  left: x - box / 2, top: y, width: box)
              end
        [art, color, strength, dx, dy]
      end
      face = smiley(x, y) if what == :star
    end
    b = Bloom.new(what: what, parts: parts, face: face, glow: glow, stars: counting_stars(x, y, size, stars),
      x: x, y: y, size: size, box: box, paint: paint, age: 0.0)
    @blooms << b
    sparks(x, y, paint, 12, size)
    giggle(x, y)
    fresh = @blooms.reject(&:fading)
    fresh.first(fresh.size - MOST_BLOOMS).each { |old| old.fading = old.age } if fresh.size > MOST_BLOOMS
    b
  end

  # A face for a star: two eyes, rosy cheeks and a smile, all sized by grow.
  def smiley(x, y)
    fill tint(INK)
    eyes = [oval(x, y, 2, center: true), oval(x, y, 2, center: true)]
    fill rgb(255, 120, 150, 0.45)
    cheeks = [oval(x, y, 2, center: true), oval(x, y, 2, center: true)]
    nofill
    stroke tint(INK)
    cap :curve
    smile = arc(x, y, 2, 2, 0, Math::PI)
    { eyes: eyes, cheeks: cheeks, smile: smile }
  end

  # Up to five stars in a row under a number, like the spots on a domino.
  def counting_stars(x, y, size, count)
    per_row = count > 5 ? (count + 1) / 2 : count
    gap = size * 0.2
    Array.new(count) do |i|
      row, col = i.divmod(per_row)
      in_row = row.zero? ? per_row : count - per_row
      { x: x + (col - (in_row - 1) / 2.0) * gap, y: y + size * 0.52 + row * gap, at: 0.35 + i * 0.18, art: nil }
    end
  end

  # Every frame: grow in with a bounce, breathe a little, and at the end
  # float up and fade. Returns true when the bloom is all gone.
  def grow(b, dt)
    b.age += dt
    t = b.age
    fade = b.fading ? smooth((t - b.fading) / FADE) : 0.0
    hop = b.hop && t > b.hop ? Math.sin(Math::PI * [(t - b.hop) / 0.4, 1].min) : 0.0
    scale = t < GROW ? 0.15 + 0.85 * springy(t / GROW) : 1 + 0.018 * Math.sin((t - GROW) * 3.2)
    size = b.size * (scale + 0.06 * hop) * (1 - 0.15 * fade)
    alpha = [t / 0.12, 1].min * (1 - fade)
    rise = 36 * fade + 26 * hop
    b.parts.each do |art, color, strength, dx, dy|
      if b.what == :star
        r = size * 0.5
        art.style(outer: r.round(1), inner: (r * 0.55).round(1), left: (b.x + dx * size).round(1),
          top: (b.y + dy * size - rise).round(1), rotate: 180, fill: tint(color, strength * alpha))
      else
        art.style(size: size.round(1), left: (b.x - b.box / 2 + dx * size).round(1),
          top: (b.y - 0.62 * size + dy * size - rise).round(1), stroke: tint(color, strength * alpha))
      end
    end
    show_face(b.face, b.x, b.y - rise, size * 0.5, alpha) if b.face
    splash(b, t) if b.glow
    count_stars(b, t, alpha, rise)
    b.fading = t if b.fading.nil? && b.hop.nil? && t > GROW + STAY && !@spelling.include?(b)
    b.fading && t - b.fading > FADE
  end

  def show_face(face, x, y, r, alpha)
    face[:eyes].each_with_index do |eye, i|
      eye.style(left: (x + (i - 0.5) * 0.36 * r).round(1), top: (y - 0.04 * r).round(1), width: (0.11 * r).round(1),
        height: (0.15 * r).round(1), fill: tint(INK, alpha))
    end
    face[:cheeks].each_with_index do |cheek, i|
      cheek.style(left: (x + (i - 0.5) * 0.62 * r).round(1), top: (y + 0.1 * r).round(1), width: (0.13 * r).round(1),
        height: (0.08 * r).round(1), fill: rgb(255, 120, 150, (0.45 * alpha).round(3)))
    end
    face[:smile].style(left: (x - 0.12 * r).round, top: (y + 0.04 * r).round, width: (0.24 * r).round,
      height: (0.18 * r).round, strokewidth: (0.035 * r).round(1), stroke: tint(INK, alpha))
  end

  # A soft white halo, and a ring of colour spreading out like a splash.
  def splash(b, t)
    halo, ring = b.glow
    g = [t / 0.9, 1].min
    d = (b.size * (0.5 + 0.9 * g)).round(1)
    halo.style(width: d, height: d, fill: tint(WHITE, 0.45 * (1 - g)))
    r = (b.size * (0.3 + 1.5 * g)).round(1)
    ring.style(width: r, height: r, strokewidth: (6 * (1 - g) + 1).round(1), stroke: tint(b.paint[0], 0.7 * (1 - g)))
    return if g < 1

    b.glow.each(&:remove)
    b.glow = nil
  end

  # A number's stars pop in one at a time, each with a note, for counting.
  def count_stars(b, t, alpha, rise)
    b.stars.each_with_index do |s, i|
      next if t < s[:at]

      unless s[:art]
        @bloom_layer.append do
          nostroke
          transform :center
          s[:art] = [star(s[:x], s[:y], 5, 2, 1, fill: tint(GOLD_SHADE)), star(s[:x], s[:y], 5, 2, 1, fill: tint(GOLD))]
        end
        @chimes.play(:pop, LADDER[5 + i])
      end
      r = (b.size * 0.08 * springy((t - s[:at]) / 0.35)).round(1)
      s[:art].each_with_index do |art, top_one|
        art.style(outer: r, inner: (r * 0.5).round(1), top: (s[:y] - rise + (top_one.zero? ? 3 : 0)).round(1), rotate: 180,
          fill: top_one.zero? ? tint(GOLD_SHADE, alpha * 0.5) : tint(GOLD, alpha))
      end
    end
  end

  def wilt(b)
    b.parts.each { |art, *| art.remove }
    b.face&.values&.flatten&.each(&:remove)
    b.glow&.each(&:remove)
    b.stars.each { |s| s[:art]&.each(&:remove) }
  end

  # ---- bits: little things that bounce, float and fade ----

  # kind is :ball, :star, :heart or :bubble. motion is :bounce (thrown, falls
  # onto the hills), :float (rises like a bubble) or :spark (flies out, slows).
  def add_bit(kind, motion, x, y, vx, vy, size, color, life)
    art = nil
    @bit_layer.append do
      nostroke
      transform :center # stars spin about their middles
      art = case kind
            when :ball then oval(x, y, size, center: true, fill: tint(color))
            when :star then star(x, y, 5, size / 2.0, size / 4.0, fill: tint(color))
            when :heart then heart(x - size / 2.0, y - size / 2.0, size, tint(color))
            else oval(x, y, size, center: true, fill: tint(color, 0.6)..tint(lighter(color, 0.75), 0.6))
            end
    end
    @bits << Bit.new(art, kind, motion, x.to_f, y.to_f, vx, vy, size, color, 0.0, life, rand * 6, 0.0)
    @bits.shift.art.remove while @bits.size > MOST_BITS
  end

  def heart(left, top, s, color)
    shape(left: left, top: top, fill: color) do
      move_to s * 0.5, s * 0.95
      curve_to s * 0.15, s * 0.7, 0, s * 0.5, 0, s * 0.32
      curve_to 0, s * 0.12, s * 0.15, s * 0.02, s * 0.28, s * 0.02
      curve_to s * 0.4, s * 0.02, s * 0.48, s * 0.1, s * 0.5, s * 0.2
      curve_to s * 0.52, s * 0.1, s * 0.6, s * 0.02, s * 0.72, s * 0.02
      curve_to s * 0.85, s * 0.02, s, s * 0.12, s, s * 0.32
      curve_to s, s * 0.5, s * 0.85, s * 0.7, s * 0.5, s * 0.95
    end
  end

  # Sparks fly out of a new bloom and slow down, and a splash of drops
  # jumps up and falls onto the hills.
  def sparks(x, y, paint, count, size)
    count.times do |i|
      angle = i * Math::PI * 2 / count + rand(-0.2..0.2)
      speed = size * rand(1.6..2.4)
      color = [paint[0], paint[0], WHITE, PAINTS.sample[0]][i % 4]
      add_bit(i.even? ? :star : :ball, :spark, x, y, Math.cos(angle) * speed, Math.sin(angle) * speed,
        rand(14..22), color, rand(0.7..0.95))
    end
    (count / 2).times do
      angle = -Math::PI / 2 + rand(-1.1..1.1)
      speed = rand(380.0..640.0)
      add_bit(:ball, :bounce, x, y, Math.cos(angle) * speed, Math.sin(angle) * speed, rand(9..15), paint[0], rand(1.4..1.9))
    end
  end

  # A click tosses a handful of balls, stars and hearts into the air.
  def toss(x, y)
    7.times do |i|
      add_bit(%i[ball star heart][i % 3], :bounce, x, y, rand(-280.0..280.0), rand(-640.0..-360.0),
        rand(34..58), PAINTS.sample[0], rand(3.2..4.0))
    end
  end

  def bubble(x, y, size = rand(16..30), rise = rand(50.0..90.0))
    add_bit(:bubble, :float, x, y, 0, -rise, size, PAINTS.sample[0], rand(1.8..2.6))
  end

  # Every frame: move, bounce, fade. Returns true when the bit is all gone.
  def move_bit(bit, dt)
    bit.age += dt
    case bit.motion
    when :bounce
      bit.vy += GRAVITY * dt
      bit.x += bit.vx * dt
      bit.y += bit.vy * dt
      floor = ground(bit.x) - bit.size / 2.0
      if bit.y > floor
        bit.y = floor
        bit.squash = [bit.vy / 900.0, 0.35].min if bit.vy > 120
        bit.vy = -bit.vy * 0.62
        bit.vx *= 0.82
      end
      bit.vx = bit.vx.abs if bit.x < bit.size / 2.0
      bit.vx = -bit.vx.abs if bit.x > width - bit.size / 2.0
    when :float
      bit.y += bit.vy * dt
      bit.x += Math.sin(bit.age * 3 + bit.spin) * 24 * dt
    else
      drag = Math.exp(-dt * 5)
      bit.vx *= drag
      bit.vy = bit.vy * drag + 90 * dt
      bit.x += bit.vx * dt
      bit.y += bit.vy * dt
    end
    left = bit.life - bit.age
    alpha = left / (bit.motion == :spark ? 0.5 : 0.8)
    alpha = [alpha, bit.age / 0.1].min if bit.motion == :float
    show_bit(bit, alpha)
    left <= 0
  end

  def show_bit(bit, alpha)
    x, y = bit.x.round(1), bit.y.round(1)
    case bit.kind
    when :ball
      # squashed flat for a moment when it lands
      squash = bit.squash
      bit.squash = [squash - 0.06, 0].max
      w, h = bit.size * (1 + squash), bit.size * (1 - squash)
      bit.art.style(left: x, top: (y + (bit.size - h) / 2).round(1), width: w.round(1), height: h.round(1),
        fill: tint(bit.color, alpha))
    when :star
      bit.art.style(left: x, top: y, rotate: ((bit.spin * 60 + bit.age * 160 * (bit.vx <=> 0)) % 360).round,
        fill: tint(bit.color, alpha))
    when :heart
      bit.art.style(left: (x - bit.size / 2.0).round(1), top: (y - bit.size / 2.0).round(1), fill: tint(bit.color, alpha))
    else
      bit.art.style(left: x, top: y, fill: tint(bit.color, 0.6 * alpha)..tint(lighter(bit.color, 0.75), 0.6 * alpha))
    end
  end

  # ---- keys with no letter on them ----

  def blow_bubbles
    6.times { |i| bubble(width * (0.3 + 0.08 * i) + rand(-20..20), ground(width / 2.0) - 10, rand(34..62), rand(110.0..170.0)) }
    %w[c5 e5 g5].each_with_index { |note, i| timer(i * 0.09) { @chimes.play(:pop, note) } }
    giggle(width / 2.0, height - 150)
  end

  # Return paints a rainbow over the hills, a band at a time. Pressed again,
  # the rainbow that is already there just stays a little longer.
  def rainbow
    %w[c5 e5 g5 c6].each_with_index { |note, i| timer(i * 0.1) { @chimes.play(:bell, note) } }
    cx, cy = width / 2.0, ground(width / 2.0) + 40
    giggle(cx, cy - 200)
    return @rainbow.each { |band| band[:age] = [band[:age], 0.4].min } if @rainbow

    @rainbow = PAINTS.first(7).each_with_index.map do |(color, _), i|
      d = [(height * 1.05 - i * 34).round, 40].max
      band = nil
      @rainbow_layer.append do
        nofill
        band = arc(cx - d / 2.0, cy - d / 2.0, d, d, Math::PI, Math::PI * 2, stroke: tint(color, 0), strokewidth: 18)
      end
      { art: band, color: color, age: -i * 0.07 }
    end
  end

  def fade_rainbow(dt)
    @rainbow.each do |band|
      band[:age] += dt
      t = band[:age]
      band[:art].style(stroke: tint(band[:color], t < 0 ? 0 : [t / 0.3, 1].min * [(2.6 - t) / 0.8, 1].min))
    end
    return unless @rainbow.all? { |band| band[:age] > 2.6 }

    @rainbow.each { |band| band[:art].remove }
    @rainbow = nil
  end

  # The arrow keys send a comet of stars flying that way.
  def comet(direction)
    dx, dy = { "left" => [-1, 0], "right" => [1, 0], "up" => [0, -1], "down" => [0, 1] }[direction]
    x, y = width / 2.0 - dx * width * 0.3, height * 0.45 - dy * height * 0.25
    paint = next_paint
    6.times do |i|
      speed = 700 - i * 70
      add_bit(:star, :spark, x - dx * i * 26, y - dy * i * 26, dx * speed + rand(-30..30), dy * speed + rand(-30..30),
        34 - i * 3, i.even? ? paint[0] : WHITE, 1.0)
    end
    %w[c5 e5 g5].each_with_index { |note, i| timer(i * 0.07) { @chimes.play(:pop, note) } }
    giggle(x + dx * 300, y + dy * 200)
  end

  # ---- a name, spelled one key at a time ----

  def spell_next
    finish_spelling if @spelling.size == @name.size
    i, n = @spelling.size, @name.size
    gap = [(width - 120) / n.to_f, bloom_size * 0.78].min
    size = [bloom_size, gap * 1.3].min
    x = width / 2.0 + (i - (n - 1) / 2.0) * gap
    @spelling << bloom(@name[i], x, height * 0.42, size: size, paint: PAINTS[i % PAINTS.size])
    @chimes.play(:bell, LADDER[4 + i % 10])
    @idle_since = @clock
    show_ribbon
    cheer if @spelling.size == n
  end

  # The whole name! Each letter hops in turn, and confetti falls.
  def cheer
    @spelling.each_with_index { |b, i| b.hop = b.age + 0.35 + i * 0.12 }
    %w[c5 e5 g5 c6 e6].each_with_index { |note, i| timer(0.3 + i * 0.12) { @chimes.play(:bell, note) } }
    timer(0.3) do
      36.times do
        add_bit(%i[ball star heart].sample, :bounce, rand(0.0..width.to_f), rand(-80.0..-10.0), rand(-80.0..80.0),
          rand(0.0..120.0), rand(14..24), PAINTS.sample[0], rand(3.0..3.8))
      end
    end
  end

  def finish_spelling
    @spelling.each { |b| b.fading ||= b.age }
    @spelling = []
  end

  # The name along the bottom: the letters spelled so far in colour, the
  # rest waiting in grey.
  def show_ribbon
    @ribbon&.remove
    @ribbon = nil
    return unless @name

    done = @spelling.size
    w = @name.size * 22 + 48
    @ribbon = stack(left: [((width - w) / 2.0).round, 1].max, bottom: 8, width: w, height: 44) do
      background tint(WHITE, 0.78), curve: 22
      letters = @name.chars.each_with_index.map do |char, i|
        span(char, stroke: i < done ? tint(PAINTS[i % PAINTS.size][0]) : tint([176, 170, 208]))
      end
      para(*letters, font: FONT, weight: "bold", size: 26, align: "center", kerning: 3, margin: [0, 5, 0, 0])
    end
  end

  # ---- the grown-up corner ----

  # The round face of a grown-up button, with a soft shadow under it.
  def grown_up_face
    nostroke
    fill rgb(40, 60, 110, 0.12)
    oval 32, 35, 62, center: true
    fill rgb(255, 255, 255, 0.88)
    oval 32, 32, 62, center: true
  end

  def toggle_sound
    @chimes.muted = !@chimes.muted
    show_sound
    @chimes.play(:pop, "g5")
    save_settings
  end

  # The speaker shows its sound waves, or a cross when it is quiet.
  def show_sound
    @sound_on.each { |part| part.hidden = @chimes.muted }
    @sound_off.each { |part| part.hidden = !@chimes.muted }
    @sound_label.replace(@chimes.muted ? "Sound off" : "Sound on")
  end

  # Holding the Name button fills a ring round it; full, the card opens.
  def name_tick
    return unless @name_hold

    held = @clock - @name_hold
    @name_ring.show
    @name_ring.style(angle2: (-Math::PI / 2 + Math::PI * 2 * [held / HOLD_FOR_NAME, 1].min).round(3))
    return if held < HOLD_FOR_NAME

    @name_hold = nil
    @name_ring.hide
    open_card
  end

  def let_go
    return unless @name_hold

    @name_hold = nil
    @name_ring.hide
    @name_hint.show
    timer(2.5) { @name_hint.hide }
  end

  def open_card
    return if @card

    w, h = 440, 210
    left, top = [(width - w) / 2, 1].max, [(height - h) / 2 - 30, 1].max
    @card_box = [left, top, w, h] # a click outside it closes the card
    @card = stack(left: 0, top: 0, width: width, height: height) do
      rect(0, 0, width, height, fill: rgb(40, 50, 90, 0.35))
      stack(left: left, top: top, width: w, height: h) do
        background white, curve: 28
        para "Type a name", font: FONT, weight: "600", size: 28, stroke: "#3a3560", align: "center", margin: [0, 26, 0, 0]
        para "Then every key spells it, one letter at a time.", size: 13, stroke: "#6d6892", align: "center",
          margin: [0, 6, 0, 16]
        flow(margin_left: 70) { @name_field = edit_line @name.to_s, width: 300 }
        flow margin: [118, 22, 0, 0] do
          button("Spell it", width: 100, margin_right: 8) { spell_it }
          button("No name", width: 100) { no_name }
        end
      end
    end
    @name_field.finish = proc { spell_it }
    @name_field.focus
  end

  def outside_card?(x, y)
    left, top, w, h = @card_box
    !(x.between?(left, left + w) && y.between?(top, top + h))
  end

  def close_card
    @card&.remove
    @card = @name_field = nil
  end

  def spell_it
    typed = @name_field.text.gsub(/[^[:alnum:]]/, "")[0, 12]
    close_card
    return no_name if typed.empty?

    @name = typed
    finish_spelling
    save_settings
    show_ribbon
    @chimes.play(:bell, "c5")
  end

  def no_name
    close_card
    @name = nil
    finish_spelling
    save_settings
    show_ribbon
  end

  # ---- leaving: hold Escape ----

  # A held key repeats, so a hold is Escape arriving again and again: the
  # second within 1.2 seconds of the first (the Mac waits a moment before
  # it repeats a key), and the rest less than half a second apart.
  def holding_escape?
    return false unless @escape_since

    @clock - @escape_last < (@escape_last == @escape_since ? 1.2 : 0.5)
  end

  def escape_held
    @escape_last = @clock
    progress = (@clock - @escape_since) / HOLD_TO_LEAVE
    @leave_ring.show
    @leave_ring.style(angle2: (-Math::PI / 2 + Math::PI * 2 * [progress, 1].min).round(3))
    @leave_label.replace(progress >= 1 ? "Bye bye!" : "Keep holding to leave")
    return if progress < 1 || @leaving

    @leaving = true
    timer(0.3) { close }
  end

  def escape_tick
    return unless @escape_since && !holding_escape?

    @escape_since = nil
    @leave_ring.hide
    @leave_label.replace("Hold esc to leave")
  end

  # ---- sixty times a second ----

  def tick
    dt = 1.0 / 60
    @clock += dt
    @frame += 1
    draw_land unless @land_size == [width, height]
    @blooms.reject! { |b| grow(b, dt).tap { |gone| wilt(b) if gone } }
    @bits.reject! { |bit| move_bit(bit, dt).tap { |gone| bit.art.remove if gone } }
    fade_rainbow(dt) if @rainbow
    sun_tick
    drift_clouds if @frame % 3 == 0
    name_tick
    escape_tick
    # a name left half spelled for a while fades, ready to start again
    return unless @name && @spelling.any? && @spelling.size < @name.size && @clock - @idle_since > 12

    finish_spelling
    show_ribbon
  end

  # ---- building it ----

  @chimes = Chimes.new
  settings = load_settings
  @chimes.muted = settings["muted"] == true
  @name = settings["name"].to_s[/\A[[:alnum:]]{1,12}\z/]
  @clock = 0.0
  @frame = 0
  @paint_turn = -1
  @blooms = []
  @bits = []
  @spelling = []
  @last_used = Array.new(8, -1.0)
  @look_at = [500, 330]
  @giggle = 0.0
  @last_key_at = -1.0
  @idle_since = 0.0
  @last_input = 0.0
  font FONT_FILE if FONT_FILE

  background "#9fd8ff".."#fff0de"
  clouds = [[250, 36, 1.0], [560, 88, 0.8], [740, 168, 0.7]] # left, top and size of each
  @cloud_x = clouds.map(&:first)
  @clouds = clouds.map { |left, top, scale| draw_cloud(left, top, scale) }
  draw_sun
  @zeds = Array.new(3) do
    para "z", font: FONT, weight: "bold", size: 14, stroke: tint([96, 112, 176], 0), left: 150, top: 78, margin: 0,
      hidden: true
  end
  @far_hill = stack(left: 0, top: 0, width: 1.0, height: 1.0) {}
  @rainbow_layer = stack(left: 0, top: 0, width: 1.0, height: 1.0) {}
  @land = stack(left: 0, top: 0, width: 1.0, height: 1.0) {}
  @glow_layer = stack(left: 0, top: 0, width: 1.0, height: 1.0) {}
  @bloom_layer = stack(left: 0, top: 0, width: 1.0, height: 1.0) {}
  @bit_layer = stack(left: 0, top: 0, width: 1.0, height: 1.0) {}

  # the grown-up corner: sound on and off, and a name to spell
  sound = stack(right: 96, top: 18, width: 64, height: 84, cursor: :hand_cursor) do
    grown_up_face
    fill "#4b4a7a"
    rect 17, 25, 9, 14, curve: 2
    shape { move_to 24, 26; line_to 34, 17; line_to 34, 47; line_to 24, 38 }
    nofill
    stroke "#4b4a7a"
    strokewidth 3
    cap :curve
    @sound_on = [arc(32, 22, 14, 20, -1.0, 1.0), arc(30, 16, 24, 32, -1.0, 1.0)]
    @sound_off = [line(40, 26, 50, 38), line(50, 26, 40, 38)]
    @sound_label = para "Sound on", size: 10, stroke: "#4b4a7a", align: "center", left: 0, top: 68, width: 64, margin: 0
  end
  sound.click { toggle_sound }
  name_button = stack(right: 20, top: 18, width: 64, height: 84, cursor: :hand_cursor) do
    grown_up_face
    nofill
    stroke "#6c63ff"
    strokewidth 5
    cap :curve
    @name_ring = arc(2, 2, 60, 60, -Math::PI / 2, -Math::PI / 2, hidden: true)
    para "Aa", font: FONT, weight: "bold", size: 20, stroke: "#4b4a7a", align: "center", left: 0, top: 18, width: 64, margin: 0
    para "Name", size: 10, stroke: "#4b4a7a", align: "center", left: 0, top: 68, width: 64, margin: 0
  end
  name_button.click { @name_hold = @clock }
  @name_hint = stack(right: 12, top: 108, width: 150, height: 30, hidden: true) do
    background tint(WHITE, 0.92), curve: 15
    para "Hold to type a name", size: 11, stroke: "#4b4a7a", align: "center", margin: [0, 8, 0, 0]
  end

  # the way out, for grown-ups
  stack(left: 14, bottom: 12, width: 220, height: 40) do
    nostroke
    fill rgb(255, 255, 255, 0.75)
    rect 0, 6, 40, 28, curve: 7
    para "esc", size: 11, weight: "bold", stroke: "#3f7d4f", left: 2, top: 13, width: 36, align: "center", margin: 0
    nofill
    stroke white
    strokewidth 3
    @leave_ring = arc(48, 6, 28, 28, -Math::PI / 2, -Math::PI / 2, hidden: true)
    @leave_label = para "Hold esc to leave", size: 12, stroke: white, left: 84, top: 12, margin: 0
  end

  show_ribbon
  show_sound

  keypress { |key| press(key) }

  click do |_button, x, y|
    @last_input = @clock
    next close_card if @card && outside_card?(x, y)
    next if @card || (x > width - 180 && y < 110) # the grown-up corner

    toss(x, y)
    @chimes.play(:pop, note_across(x))
    giggle(x, y)
  end
  release { let_go }

  # A wiggle leaves bubbles behind the pointer, with a quiet twinkle now and then.
  motion do |x, y|
    @look_at = [x, y]
    @last_input = @clock
    @wiggle_from ||= [x, y]
    next if @card || Math.hypot(x - @wiggle_from[0], y - @wiggle_from[1]) < 36

    @wiggle_from = [x, y]
    bubble(x, y)
    next if @clock - (@twinkled_at || -1) < 0.3

    @twinkled_at = @clock
    @chimes.play(:twinkle, LADDER[(12 - y / height.to_f * 9).round.clamp(0, LADDER.size - 1)])
  end

  wheel do |_delta, x, y|
    @last_input = @clock
    bubble(x + rand(-20..20), y + rand(-20..20)) unless @card
  end

  animate(60) { tick }
end
