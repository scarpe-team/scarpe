# Night Light: a sleepy sky to watch before bed. For ages 2 and up.
#
# Everything does something. Tap the moon and it changes shape. Tap a star and
# it sings its note; tap the empty sky and a new star appears. The fireflies
# follow the pointer and chime when you touch them, and tapping the grass sends
# up another. The sheep hop, the clouds sigh, the cottage light clicks on and
# off, and any key makes a star sing (the space bar sends a shooting star).
#
# The big star in the corner plays a music-box lullaby. After a few minutes the
# sky slowly softens, the cottage light goes out and the moon closes its eyes,
# until the moon is the brightest thing left, glowing like a night light.
#
# For grown-ups: the speaker button turns every sound off and on, and holding
# Escape for two seconds closes the window (Cmd-Q works too). Nothing is saved
# and nothing leaves the computer.
#
# The sounds are made right here in plain Ruby: each one is worked out as
# numbers, written once to a small WAV file and played with afplay. They all use
# the same five notes (a pentatonic scale), so whatever gets tapped, however
# fast, it sounds lovely with the lullaby.

require "tmpdir"
require "fileutils"

W, H = 960, 640
FPS = 30
MOON_X, MOON_Y, MOON_R = 712, 196, 86
SOFTEN_AFTER = 240.0 # seconds until the sky is as soft as it gets
K = 0.5523           # a curve handle this long draws a quarter of a circle
HIGH_TO_LOW = %w[a6 g6 e6 d6 c6 a5 g5 e5 d5 c5] # the higher a star, the higher it sings

# The lullaby, as [note, beats]. Three beats make a bar, like a slow waltz, and
# every note comes from the pentatonic scale C D E G A.
LULLABY = [
  ["g4", 2], ["e5", 1], ["d5", 2], ["c5", 1], ["a4", 2], ["c5", 1], ["g4", 3],
  ["g4", 2], ["e5", 1], ["d5", 2], ["e5", 1], ["g5", 2], ["e5", 1], ["d5", 3],
  ["e5", 1], ["g5", 1], ["e5", 1], ["d5", 2], ["c5", 1], ["a4", 1], ["c5", 1], ["d5", 1], ["e5", 3],
  ["g4", 2], ["e5", 1], ["d5", 2], ["c5", 1], ["a4", 2], ["d5", 1], ["c5", 3],
]
BASS = %w[c3 g3 a3 c3 c3 g3 a3 g3 c3 a3 e3 g3 c3 g3 a3 c3] # a low note to start each bar
BEAT = 0.8 # seconds
PLAYS = 3  # times through before the music box winds down

# Fredoka, the round font the Kids apps share. It travels with the app (in fonts,
# loose beside it, or in _fonts), and in a Scarpe checkout it sits in the _fonts
# folder next door: the same four places every Kids app looks. Without it, the
# words still show in a fallback face.
FREDOKA = %w[fonts . _fonts ../_fonts].map { |dir| File.expand_path("#{dir}/Fredoka.ttf", __dir__) }.find { |path| File.exist?(path) }
ROUND = (FREDOKA && font(FREDOKA)&.first) || "Arial Rounded MT Bold, Helvetica, sans-serif"

Star = Struct.new(:x, :y, :size, :art, :glow, :halo, :phase, :speed, :note, :lit, :life)
Firefly = Struct.new(:x, :y, :vx, :vy, :slot, :halo, :core, :phase, :note, :lit, :rest, :orbit, :goal, :shown, :settled)
Cloud = Struct.new(:x, :y, :speed, :art, :width, :alpha, :wobble, :shown)
Sheep = Struct.new(:x, :y, :slot, :awake, :asleep, :hop, :note)
Mote = Struct.new(:art, :x, :y, :vx, :vy, :age, :life) # stardust, music notes and sleepy z's

# The sounds. Each is a list of numbers worked out once, written to a WAV file
# once, and handed to afplay whenever it is wanted.
class Sounds
  RATE = 22_050
  LEVELS = { tine: 0.26, chime: 0.16, twinkle: 0.18, bong: 0.24, sigh: 0.13, hop: 0.2, tick: 0.14 }
  AT_ONCE = 6 # however fast the taps come, no more than this many sounds at the same moment
  NOTES = %w[c c# d d# e f f# g g# a a# b]

  attr_reader :last_file, :player
  attr_accessor :muted

  def initialize
    @dir = Dir.mktmpdir("night-light")
    at_exit { FileUtils.rm_rf(@dir) }
    @files = {}
    @playing = []
  end

  # play(:chime, "e6") plays one voice at one note, a little quieter when volume is below 1.
  def play(voice, note, volume = 1.0)
    return if muted

    @playing.select!(&:alive?)
    return if @playing.size >= AT_ONCE

    name = "#{voice}-#{note}"
    @last_file = @files[name] ||= write(name, level(send(voice, hz(note)), LEVELS.fetch(voice)))
    @player = Process.detach(spawn("afplay", "-v", volume.round(2).to_s, @last_file, out: File::NULL, err: File::NULL))
    @playing << @player
  rescue SystemCallError
    # no afplay here (not a Mac): the sky stays quiet
  end

  private

  # A music-box tine: a pure note with a faint metal ring that fades first.
  def tine(hz)
    sound(2.2) { |t| (wave(hz, t) + 0.2 * wave(hz * 6.1, t) * Math.exp(-t * 14)) * Math.exp(-t * 2.2) * rise(t, 0.003) }
  end

  # A firefly's chime: high and glassy, and gone in a second.
  def chime(hz)
    sound(1.2) { |t| (wave(hz, t) + 0.25 * wave(hz * 2, t) * Math.exp(-t * 6)) * Math.exp(-t * 4.5) * rise(t, 0.004) }
  end

  # A star's twinkle: a soft triangle wave, like a tiny xylophone bar.
  def twinkle(hz)
    sound(1.0) { |t| (wave(hz, t) + wave(hz * 3, t) / 9 + wave(hz * 5, t) / 25) * Math.exp(-t * 5) * rise(t, 0.003) }
  end

  # The moon's bong: low and round like a singing bowl, two tones a hair apart so it shimmers.
  def bong(hz)
    sound(3.0) { |t| (wave(hz, t) + wave(hz * 1.003, t) + 0.3 * wave(hz * 2.76, t) * Math.exp(-t * 3)) * Math.exp(-t * 1.5) * rise(t, 0.02) }
  end

  # A cloud's sigh: a note, its fifth and its octave, swelling in and fading away.
  def sigh(hz)
    sound(1.6) { |t| (wave(hz, t) + wave(hz * 1.5, t) + 0.6 * wave(hz * 2, t)) * Math.sin(Math::PI * t / 1.6)**2 }
  end

  # A sheep's hop: a small boing that slides up into its note.
  def hop(hz)
    phase = 0.0
    sound(0.4) do |t|
      phase += hz * (0.75 + 0.25 * [t / 0.1, 1].min) / RATE
      Math.sin(2 * Math::PI * phase) * Math.exp(-t * 8) * rise(t, 0.005)
    end
  end

  # The cottage's light switch: a short wooden tick with a warm note in it.
  def tick(hz)
    sound(0.5) { |t| (0.7 * wave(hz, t) + 0.3 * wave(hz * 2, t)) * Math.exp(-t * 12) * rise(t, 0.001) }
  end

  def wave(hz, t) = Math.sin(2 * Math::PI * hz * t)

  # How far a sound has faded in, so none of them starts with a click.
  def rise(t, seconds) = [t / seconds, 1].min

  # `seconds` of sound: one number for each moment t, the last hundredth of a second fading out.
  def sound(seconds)
    Array.new((RATE * seconds).round) do |i|
      t = i.fdiv(RATE)
      yield(t) * [(seconds - t) * 100, 1].min
    end
  end

  # Every voice is scaled so its loudest moment is its level, and every level is
  # well under full volume: nothing here is ever loud.
  def level(samples, peak)
    top = samples.map(&:abs).max
    samples.map { |sample| sample * peak / top }
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

Shoes.app(title: "Night Light", width: W, height: H, resizable: false) do
  # ---------------------------------------------------------------- drawing kit

  # A slot or a text block reads a number from 0 to 1 as a fraction of its
  # parent, so anything moved to such a spot goes to a whole pixel instead. (It
  # reads a negative number as that far in from the far edge, which is why the
  # slots and words here are kept inside the window, and why clouds are shapes.)
  def px(v)
    v > 0 && v <= 1 ? v.round : v.round(1)
  end

  # Slow at both ends and quicker in the middle, for anything that moves.
  def ease(k)
    k = k.clamp(0.0, 1.0)
    k * k * (3 - 2 * k)
  end

  # The tops of the two hills, at any x across the window.
  def far_hill(x) = 452 + 16 * Math.sin(x / 210.0 + 3.5) + 5 * Math.sin(x / 90.0 + 1)
  def near_hill(x) = 532 + 14 * Math.sin(x / 170.0 + 1.2) + 6 * Math.sin(x / 70.0)

  # A hill: its top follows the function, every 16 pixels, down to the bottom of the window.
  def hill(&top)
    shape do
      move_to 0, top.call(0)
      (16..W).step(16) { |x| line_to x, top.call(x) }
      line_to W, H
      line_to 0, H
    end
  end

  # The sunlit part of a moon of radius r, in a box 2r wide. `side` is 1 when the
  # light comes from the right and -1 from the left. `bulge` is where the shadow's
  # edge crosses the middle: 1 at the lit edge (no moon at all), 0 down the
  # middle (half a moon) and -1 at the far edge (a full moon).
  def sunlit(r, bulge, side)
    e = r * bulge
    shape do
      move_to r, 0
      curve_to r + side * r * K, 0, r + side * r, r - r * K, r + side * r, r
      curve_to r + side * r, r + r * K, r + side * r * K, 2 * r, r, 2 * r
      curve_to r + side * e * K, 2 * r, r + side * e, r + r * K, r + side * e, r
      curve_to r + side * e, r - r * K, r + side * e * K, 0, r, 0
    end
  end

  # A cloud w wide and h tall: a flat bottom, round ends and three puffs on top.
  def puffy(left, top, w, h)
    x = ->(u) { u * w }
    y = ->(v) { v * h }
    shape(left: left, top: top) do
      move_to x.(0.14), y.(1.0)
      line_to x.(0.86), y.(1.0)
      curve_to x.(0.99), y.(1.0), x.(0.99), y.(0.5), x.(0.86), y.(0.48)
      curve_to x.(0.88), y.(0.12), x.(0.68), y.(0.1), x.(0.64), y.(0.3)
      curve_to x.(0.62), y.(-0.2), x.(0.38), y.(-0.2), x.(0.36), y.(0.26)
      curve_to x.(0.3), y.(0.02), x.(0.1), y.(0.1), x.(0.15), y.(0.5)
      curve_to x.(0.01), y.(0.52), x.(0.01), y.(1.0), x.(0.14), y.(1.0)
    end
  end

  # A five-pointed star, turned a little by `angle` (in degrees), drawn as its outline.
  def pointy(x, y, r, angle)
    points = Array.new(10) do |i|
      a = (angle - 90 + i * 36) * Math::PI / 180
      reach = i.even? ? r : r * 0.45
      [x + Math.cos(a) * reach, y + Math.sin(a) * reach]
    end
    shape do
      move_to(*points.first)
      points.drop(1).each { |x2, y2| line_to x2, y2 }
      line_to(*points.first)
    end
  end

  # A little music note, for the lullaby to send up into the sky.
  def quaver
    stack(left: 0, top: 0, width: 24, height: 30, hidden: true) do
      nostroke
      fill rgb(255, 236, 170)
      oval 7, 23, 11, 8, center: true
      rect 11, 2, 2.4, 21
      shape { move_to 11, 2; curve_to 17, 5, 20, 9, 18, 15; curve_to 17, 11, 15, 9, 13.4, 8.5; line_to 13.4, 2 }
    end
  end

  # ---------------------------------------------------------------- the sky

  def sky
    background "#141a44".."#46397f"
    nostroke
    field = Random.new(7)
    170.times do
      x, y = field.rand(0.0..W), field.rand(0.0..470)
      next if Math.hypot(x - MOON_X, y - MOON_Y) < MOON_R + 20

      oval x, y, field.rand(1.2..2.6), center: true, fill: rgb(230, 235, 255, field.rand(0.2..0.7))
    end
  end

  # The twinkling stars: spread out, clear of the moon and the buttons.
  def place_stars
    spots = Random.new(11)
    stars = []
    until stars.size == 30
      x, y = spots.rand(30..W - 30), spots.rand(24..400)
      next if Math.hypot(x - MOON_X, y - MOON_Y) < MOON_R + 60 || (x < 250 && y < 140) || (x.between?(150, 320) && y > 320)
      next if stars.any? { |s| Math.hypot(s.x - x, s.y - y) < 80 }

      stars << Star.new(x, y, spots.rand(7.0..13.0), nil, nil, nil, spots.rand * 6, spots.rand(0.6..1.5),
        HIGH_TO_LOW[(y / 41).clamp(0, 9)], 0.0, nil)
    end
    stars
  end

  def draw_stars(stars)
    nostroke
    stars.each do |spot|
      spot.halo = oval spot.x, spot.y, spot.size * 8, center: true, fill: rgb(255, 226, 150, 0), hidden: true
      spot.glow = oval spot.x, spot.y, spot.size * 3.5, center: true, fill: rgb(255, 236, 170, 0), hidden: true
      fill rgb(255, 244, 205)
      spot.art = pointy(spot.x, spot.y, spot.size, (spot.phase * 30).round % 72)
    end
  end

  # New stars, made by tapping the empty sky. They shine a while, then fade.
  def spare_stars
    nostroke
    Array.new(10) do
      halo = oval 0, 0, 72, center: true, fill: rgb(255, 226, 150, 0), hidden: true
      glow = oval 0, 0, 32, center: true, fill: rgb(255, 236, 170, 0), hidden: true
      art = star 0, 0, 5, 9, 4, fill: rgb(255, 250, 225), hidden: true
      Star.new(0, 0, 9, art, glow, halo, 0, 1.2, "c6", 0.0, 0.0)
    end
  end

  # Twinkling is slow on purpose: a star brightens and dims over seconds, never
  # in flickers. The stars take turns, a few each frame (just one once the sky
  # is asleep), and any that are singing change every frame.
  def twinkle
    soft = 1 - 0.4 * ease(@sleepy)
    everyone = @stars + @new_stars
    turn = (@twinkle_turn...@twinkle_turn + (calm? ? 1 : quiet? ? 2 : 3)).map { |i| i % everyone.size }
    @twinkle_turn = (turn.last + 1) % everyone.size
    everyone.each_with_index do |spot, i|
      next if spot.life && spot.life <= 0
      next unless turn.include?(i) || spot.lit > 0

      spot.lit = [spot.lit - 0.04, 0].max
      shine = (0.55 + 0.45 * Math.sin(@clock * spot.speed + spot.phase)) * soft
      shine *= [spot.life / 3.0, @clock - spot.phase, 1].min if spot.life
      spot.art.style(fill: rgb(255, 244 + (11 * spot.lit).round, 205 + (50 * spot.lit).round, [shine + spot.lit, 1].min.round(2)))
      spot.glow.style(fill: rgb(255, 236, 170, (0.14 * spot.lit).round(3)), hidden: spot.lit.zero?)
      spot.halo.style(fill: rgb(255, 226, 150, (0.045 * spot.lit).round(3)), hidden: spot.lit.zero?)
    end
    @new_stars.each do |spot|
      next unless spot.life > 0

      spot.life -= 1.0 / FPS
      [spot.art, spot.glow, spot.halo].each(&:hide) if spot.life <= 0
    end
  end

  def sing(spot)
    spot.lit = 1.0
    sound :twinkle, spot.note
    dust(spot.x, spot.y, 4)
  end

  def new_star(x, y)
    spot = @new_stars.find { |s| s.life <= 0 } || @new_stars.min_by(&:life)
    spot.x, spot.y, spot.life, spot.lit, spot.phase = x, y, 25.0, 1.0, @clock
    spot.note = HIGH_TO_LOW[(y / 45).clamp(0, 9)]
    [spot.art, spot.glow, spot.halo].each { |part| part.style(left: x, top: y, hidden: false) }
    sound :twinkle, spot.note
    dust(x, y, 8)
  end

  # ---------------------------------------------------------------- the moon

  def moon
    nostroke
    # the moon's glow: seven rings, the outer ones fainter, so it fades away without an edge
    7.times { |i| oval MOON_X, MOON_Y, MOON_R * 2 + 250 - i * 34, center: true, fill: rgb(255, 232, 170, 0.016 + 0.008 * i) }
    nofill
    strokewidth 3
    @rings = Array.new(3) { { art: oval(MOON_X, MOON_Y, MOON_R * 2, center: true, stroke: rgb(255, 236, 180, 0), hidden: true), age: 9.0 } }
    r = MOON_R
    @moon = stack(left: MOON_X - r, top: MOON_Y - r, width: 2 * r, height: 2 * r) do
      nostroke
      fill rgb(175, 185, 245, 0.2) # the shadowed part, lit faintly by the earth
      oval 0, 0, 2 * r, 2 * r
      @shade_face = face(rgb(225, 230, 255, 0.5), nil)
      @lit = stack(left: 0, top: 0, width: 2 * r, height: 2 * r) {}
    end
    draw_lit
  end

  # A moon face: eyes that open and shut, cheeks, and a mouth that can say "oh".
  def face(ink, cheek)
    r = MOON_R
    nostroke
    fill ink
    eyes = [-28, 28].map { |dx| oval r + dx, r - 12, 11, 14, center: true }
    shine = cheek ? [-28, 28].map { |dx| oval r + dx + 2, r - 16, 3.5, center: true, fill: rgb(255, 255, 255, 0.9) } : []
    if cheek
      fill cheek
      [-48, 48].each { |dx| oval r + dx, r + 12, 22, 13, center: true }
    end
    nofill
    stroke ink
    strokewidth 3.5
    cap :curve
    shut = [-28, 28].map { |dx| shape { move_to r + dx - 7, r - 12; curve_to r + dx - 3, r - 6, r + dx + 3, r - 6, r + dx + 7, r - 12 } }
    smile = shape { move_to r - 15, r + 20; curve_to r - 7, r + 30, r + 7, r + 30, r + 15, r + 20 }
    nostroke
    fill ink
    oh = oval r, r + 24, 13, 15, center: true
    { eyes: eyes, shine: shine, shut: shut, smile: smile, oh: oh }
  end

  # The sunlit part, cut to shape by a mask. It has its own face in warm colours,
  # so wherever the light falls the face is lit too, and the shadow keeps the pale one.
  def draw_lit
    r = MOON_R
    turn = (@phase / 8.0) % 1
    @lit.clear do
      nostroke
      fill "#fff8dc".."#ffd97c"
      oval 0, 0, 2 * r, 2 * r
      fill rgb(226, 178, 96, 0.22)
      [[40, 44, 26, 19], [-44, -34, 18, 14], [-10, 50, 14, 10], [52, -30, 12, 9]].each do |dx, dy, w, h|
        oval r + dx, r + dy, w, h, center: true
      end
      @lit_face = face("#6b4a2e", rgb(255, 128, 128, 0.35))
      mask do
        nostroke
        fill black
        sunlit(r, Math.cos(2 * Math::PI * turn), turn < 0.5 ? 1 : -1)
      end
    end
    @face_state = nil
    show_face
  end

  # Which face the moon wears: eyes open or shut, looking where, and a smile or an "oh".
  def show_face
    awake = @clock < @startled_until || (@sleepy < 0.65 && !blinking?)
    oh = @clock < @startled_until - 1.6
    look = @look || [0, 0]
    state = [awake, oh, look]
    return if state == @face_state

    @face_state = state
    [@lit_face, @shade_face].each do |parts|
      parts[:eyes].each_with_index do |eye, i|
        eye.style(left: MOON_R + [-28, 28][i] + look[0], top: MOON_R - 12 + look[1], hidden: !awake)
      end
      parts[:shine].each_with_index do |dot, i|
        dot.style(left: MOON_R + [-26, 30][i] + look[0], top: MOON_R - 16 + look[1], hidden: !awake)
      end
      parts[:shut].each { |lid| lid.hidden = awake }
      parts[:smile].hidden = oh
      parts[:oh].hidden = !oh
    end
  end

  def blinking?
    (@clock % 5.3) < 0.14
  end

  def look_at(x, y)
    @look = [((x - MOON_X) / 120.0).clamp(-3, 3).round, ((y - MOON_Y) / 120.0).clamp(-2, 3).round]
  end

  # Tapping the moon moves it on an eighth of the way round its phases.
  def turn_moon
    @phase_from = @phase
    @phase_to += 1
    @phase_to += 1 if @phase_to % 8 == 0 # skip the new moon: there would be nothing left to tap
    @turned_at = @clock
    @startled_until = @clock + 2.2
    sound :bong, %w[g3 a3 c4 d4 e4 g4 a4 c5][@phase_to % 8]
    @rings.max_by { |ring| ring[:age] }[:age] = 0.0
    @bob = 0.0
    show_face
  end

  def spin_moon
    return unless @turned_at

    k = ease((@clock - @turned_at) / 1.1)
    @phase = @phase_from + (@phase_to - @phase_from) * k
    draw_lit
    @turned_at = nil if k >= 1
  end

  # A tap sends rings out from the moon and gives it a little bounce.
  def ripple(dt)
    @rings.each do |ring|
      next if ring[:age] > 1

      ring[:age] += dt / 1.3
      d = (MOON_R * 2 + 140 * ring[:age]).round
      ring[:art].style(width: d, height: d, hidden: ring[:age] > 1, stroke: rgb(255, 236, 180, (0.5 * (1 - ring[:age])).round(3)))
    end
    return unless @bob

    @bob += dt
    lift = 10 * Math.sin(@bob * 11) * Math.exp(-@bob * 4)
    @moon.move(MOON_X - MOON_R, px(MOON_Y - MOON_R - lift))
    @bob = nil if @bob > 1.5
  end

  # ---------------------------------------------------------------- clouds

  # Each cloud is one shape. Shapes (unlike slots) can hang off the left edge of
  # the window, which is how a cloud drifts back in after floating away.
  def clouds
    nostroke
    [[40, 250, 230, 0.34, 7], [430, 132, 180, 0.28, 11], [760, 300, 210, 0.3, 5], [240, 60, 150, 0.22, 9]].map do |x, y, w, alpha, speed|
      fill rgb(236, 232, 255, alpha)..rgb(170, 168, 232, alpha * 0.55)
      Cloud.new(x.to_f, y.to_f, speed, puffy(x + 4, y + 12, w, w * 0.42), w, alpha, nil)
    end
  end

  def drift_clouds(dt)
    @cloud_tick = !@cloud_tick
    return if @clock > @busy_until && @cloud_tick # quiet: clouds step every other frame

    dt *= 2 if @clock > @busy_until
    @clouds.each do |cloud|
      cloud.x += cloud.speed * dt * (1 - 0.5 * @sleepy)
      cloud.x = -cloud.width - 20.0 if cloud.x > W + 20
      lift = 0
      if cloud.wobble
        cloud.wobble += dt
        lift = 7 * Math.sin(cloud.wobble * 10) * Math.exp(-cloud.wobble * 3)
        cloud.wobble = nil if cloud.wobble > 1.6
      end
      spot = [cloud.x.round + 4, (cloud.y + lift).round + 12]
      next if spot == cloud.shown

      cloud.shown = spot
      cloud.art.style(left: spot[0], top: spot[1])
    end
  end

  def cloud_at(x, y)
    @clouds.find { |c| x.between?(c.x + 8, c.x + c.width) && y.between?(c.y + 8, c.y + c.width * 0.45 + 10) }
  end

  def poke_cloud(cloud)
    cloud.wobble = 0.0
    sound :sigh, %w[c4 d4 g3 a3][@clouds.index(cloud)]
    5.times { |i| dust(cloud.x + cloud.width * (0.25 + i * 0.12), cloud.y + cloud.width * 0.42, 1, fall: true) }
  end

  # ---------------------------------------------------------------- the hills, the cottage and the sheep

  def hills
    nostroke
    fill "#2c2d64".."#1c1c47"
    hill { |x| far_hill(x) }
    cottage 200, far_hill(235) + 8
    nostroke
    fill "#1b3350".."#10203a"
    hill { |x| near_hill(x) }
    stroke rgb(90, 150, 140, 0.5)
    strokewidth 2
    cap :curve
    grass = Random.new(5)
    44.times do
      x = grass.rand(0..W)
      y = near_hill(x) + grass.rand(8..96)
      line x, y, x - 3, y - grass.rand(6..12)
      line x + 3, y, x + 5, y - grass.rand(5..10)
    end
  end

  def cottage(x, y)
    nostroke
    fill "#4a4386".."#37316b"
    rect x, y - 46, 70, 48
    fill "#3a3474"
    rect x + 50, y - 84, 11, 24
    fill "#5d5299".."#3b3573"
    shape { move_to x - 10, y - 44; line_to x + 35, y - 82; line_to x + 80, y - 44; line_to x - 10, y - 44 }
    fill "#2a2556"
    shape { move_to x + 10, y + 2; line_to x + 10, y - 20; curve_to x + 10, y - 30, x + 25, y - 30, x + 25, y - 20; line_to x + 25, y + 2 }
    fill rgb(255, 214, 140, 0.9)
    oval x + 22, y - 10, 3, center: true
    @window_glow = [58, 40, 26].map { |d| oval x + 45, y - 22, d, center: true, fill: rgb(255, 208, 120, 0.09) }
    @window = rect x + 36, y - 31, 18, 17, curve: 3, fill: "#ffd98a"
    stroke "#4a4386"
    strokewidth 2
    line x + 45, y - 31, x + 45, y - 14
    line x + 36, y - 22.5, x + 54, y - 22.5
    @cottage_box = [x - 10, y - 84, x + 80, y + 2]
  end

  def light_window(on)
    @window_on = on
    @window.fill = on ? "#ffd98a" : "#2d2860"
    @window_glow.each { |glow| glow.hidden = !on }
  end

  # Three sheep asleep on the hill: a woolly body of overlapping puffs, a dark
  # face, and eyes that stay shut unless someone makes them hop.
  def flock
    [[420, 8, "d5"], [596, 22, "e5"], [772, 4, "g5"]].map do |x, drop, note|
      y = (near_hill(x + 60) + drop).round
      awake = asleep = nil
      slot = stack(left: x, top: y, width: 124, height: 90) do
        nostroke
        fill rgb(8, 12, 30, 0.32)
        oval 56, 78, 96, 12, center: true
        fill "#3d3560"
        rect 26, 62, 9, 14, curve: 4
        rect 70, 62, 9, 14, curve: 4
        fill "#cfc6ec"
        [[54, 52, 88, 40], [22, 48, 30], [36, 34, 32], [58, 30, 34], [80, 36, 30], [30, 60, 28], [70, 60, 30]].each do |cx, cy, w, h|
          oval cx, cy + 3, w, h || w, center: true
        end
        fill "#fbf8ff"
        [[54, 50, 84, 36], [22, 46, 28], [36, 32, 30], [58, 28, 32], [80, 34, 28], [32, 56, 24], [68, 56, 26]].each do |cx, cy, w, h|
          oval cx, cy, w, h || w, center: true
        end
        fill "#5f5585"
        oval 88, 30, 13, 8, center: true
        oval 114, 30, 13, 8, center: true
        fill "#71679a"
        oval 101, 44, 28, 30, center: true
        fill "#fbf8ff"
        oval 96, 29, 13, center: true
        oval 105, 28, 12, center: true
        fill rgb(255, 150, 170, 0.35)
        oval 93, 51, 7, 4, center: true
        oval 110, 51, 7, 4, center: true
        nofill
        stroke "#efe9ff"
        strokewidth 2
        cap :curve
        asleep = [95, 107].map { |ex| shape { move_to ex - 4, 43; curve_to ex - 2, 46, ex + 2, 46, ex + 4, 43 } }
        nostroke
        awake = [95, 107].flat_map do |ex|
          [oval(ex, 43, 8, 9, center: true, fill: white, hidden: true), oval(ex + 1, 44, 4, center: true, fill: "#2a2350", hidden: true)]
        end
      end
      Sheep.new(x, y, slot, awake, asleep, nil, note)
    end
  end

  def sheep_at(x, y)
    @sheep.find { |s| x.between?(s.x, s.x + 124) && y.between?(s.y + 8, s.y + 84) }
  end

  def hop(sheep)
    return if sheep.hop

    sheep.hop = 0.0
    sheep.awake.each(&:show)
    sheep.asleep.each(&:hide)
    sound :hop, sheep.note
  end

  def bounce_sheep(dt)
    @sheep.each do |sheep|
      next unless sheep.hop

      sheep.hop += dt
      k = sheep.hop / 0.6
      lift = k < 1 ? 44 * Math.sin(Math::PI * k) : 0
      sheep.slot.move(sheep.x, px(sheep.y - lift))
      next if k < 1.8

      sheep.hop = nil
      sheep.awake.each(&:hide)
      sheep.asleep.each(&:show)
      snore(sheep.x + 104, sheep.y + 2)
    end
  end

  # ---------------------------------------------------------------- fireflies

  def new_firefly(x, y)
    halo = core = nil
    slot = stack(left: x - 32, top: y - 32, width: 64, height: 64) do
      nostroke
      [[58, 0.014], [42, 0.026], [26, 0.05]].each { |d, a| oval 32, 32, d, center: true, fill: rgb(214, 255, 120, a) }
      halo = oval 32, 32, 12, center: true, fill: rgb(230, 255, 150, 0.2)
      core = oval 32, 32, 5, center: true, fill: "#fbffd8"
    end
    Firefly.new(x.to_f, y.to_f, 0.0, 0.0, slot, halo, core, rand * 6, %w[c6 d6 e6 g6 a6].sample, 0.0, 0.0, rand * 6, nil, nil)
  end

  def meadow_spot
    x = rand(40.0..W - 40)
    [x, near_hill(x) - rand(10.0..120.0)]
  end

  # Each firefly drifts about the meadow; while the pointer moves they gather
  # round it, and one you touch chimes and darts off. When nobody has played for
  # a while, all but one land in the grass and glow there, taking turns, until
  # someone comes back. The first one keeps watch.
  def flutter(dt)
    @glow_turn = (@glow_turn + 1) % @fireflies.size
    @fireflies.each_with_index do |firefly, i|
      if quiet? && i > 0
        settle(firefly, i, dt)
      else
        firefly.settled = false
        fly(firefly, dt)
      end
    end
  end

  # A resting firefly glides down to a spot in the grass, closing part of the
  # gap each frame, and stays there, its light changing only when its turn comes.
  def settle(firefly, i, dt)
    return glow(firefly, dt * @fireflies.size) if firefly.settled && i == @glow_turn
    return if firefly.settled

    firefly.goal = [firefly.x.round, (near_hill(firefly.x) + 14 + i * 3 % 40).round] unless firefly.goal && firefly.goal[1] > near_hill(firefly.x)
    step = [2.0 * dt, 1].min
    firefly.x += (firefly.goal[0] - firefly.x) * step
    firefly.y += (firefly.goal[1] - firefly.y) * step
    firefly.vx = firefly.vy = 0.0
    firefly.settled = Math.hypot(firefly.goal[0] - firefly.x, firefly.goal[1] - firefly.y) < 1.5
    firefly.slot.move(px(firefly.x - 32), px(firefly.y - 32))
    glow(firefly, dt)
  end

  def fly(firefly, dt)
    near_goal = firefly.goal && Math.hypot(firefly.goal[0] - firefly.x, firefly.goal[1] - firefly.y) < 20
    firefly.goal = meadow_spot if firefly.goal.nil? || near_goal
    gx, gy = firefly.goal
    chasing = @pointer && @clock - @moved_at < 4
    if chasing
      turn = firefly.orbit + @clock * 0.7
      gx = @pointer[0] + Math.cos(turn) * 70
      gy = @pointer[1] + Math.sin(turn) * 45
    end
    pull = chasing ? 2.2 : 0.5
    firefly.vx += ((gx - firefly.x) * pull + Math.sin(@clock * 1.7 + firefly.phase) * 30) * dt
    firefly.vy += ((gy - firefly.y) * pull + Math.cos(@clock * 1.3 + firefly.phase) * 30) * dt
    firefly.vx *= 0.94
    firefly.vy *= 0.94
    firefly.x = (firefly.x + firefly.vx * dt).clamp(32, W - 32) # its slot must stay in the window
    firefly.y = (firefly.y + firefly.vy * dt).clamp(32, H - 32)
    firefly.rest -= dt
    near = @pointer && Math.hypot(@pointer[0] - firefly.x, @pointer[1] - firefly.y) < 28
    touch(firefly) if near && firefly.rest <= 0 && @clock - @moved_at < 0.2
    firefly.slot.move(px(firefly.x - 32), px(firefly.y - 32))
    glow(firefly, dt)
  end

  def touch(firefly)
    firefly.rest = 1.4
    firefly.lit = 1.0
    away = Math.atan2(firefly.y - @pointer[1], firefly.x - @pointer[0])
    firefly.vx += Math.cos(away) * 160
    firefly.vy += Math.sin(away) * 160
    sound :chime, firefly.note
  end

  # A firefly's light swells and fades slowly, about once every four seconds.
  # A settled firefly's glow changes in bigger, rarer steps.
  def glow(firefly, dt)
    firefly.lit = [firefly.lit - dt * 1.2, 0].max
    shine = (0.5 + 0.5 * Math.sin(@clock * 1.6 + firefly.phase))**2 * (1 - 0.4 * @sleepy)
    steps = firefly.settled ? 6 : 20 # a slow glow in a few steps costs few redraws
    level = ((shine + firefly.lit) * steps).round / steps.to_f
    return true if level == firefly.shown

    firefly.shown = level
    firefly.halo.style(fill: rgb(230, 255, 150, (0.08 + 0.22 * [level, 1.5].min).round(3)))
    firefly.core.style(fill: rgb(251, 255, 216, [0.4 + 0.6 * level, 1].min.round(2)))
    true
  end

  # Tapping the grass sends a firefly up from that spot: a new one while there
  # is room, otherwise the one furthest away.
  def rise_from(x, y)
    firefly = if @fireflies.size < 22
      @meadow.append { @fireflies << new_firefly(x, y) }
      @fireflies.last
    else
      @fireflies.max_by { |f| Math.hypot(f.x - x, f.y - y) }
    end
    firefly.x, firefly.y, firefly.vx, firefly.vy, firefly.lit, firefly.rest = x.to_f, y.to_f, 0.0, -140.0, 1.0, 0.6
    firefly.goal = [x + rand(-80.0..80.0), y - rand(90.0..180.0)]
    sound :chime, firefly.note
  end

  # ---------------------------------------------------------------- stardust, music notes, z's

  def motes
    nostroke
    @dust = Array.new(28) { Mote.new(star(0, 0, 4, 5, 1.8, fill: rgb(255, 240, 190), hidden: true), 0, 0, 0, 0, 9, 1) }
    @quavers = Array.new(6) { Mote.new(quaver, 0, 0, 0, 0, 9, 1) }
    @zees = Array.new(4) do
      art = para("z", font: ROUND, size: 18, weight: "bold", stroke: rgb(230, 228, 255), left: 0, top: 0, margin: 0, hidden: true)
      Mote.new(art, 0, 0, 0, 0, 9, 1)
    end
  end

  def launch(pool, x, y, vx, vy, life)
    mote = pool.find { |m| m.age >= m.life } || pool.max_by { |m| m.age / m.life }
    mote.x, mote.y, mote.vx, mote.vy, mote.age, mote.life = x.to_f, y.to_f, vx, vy, 0.0, life
    mote.art.show
    mote
  end

  def dust(x, y, count, fall: false)
    count.times do
      angle = rand * 2 * Math::PI
      speed = fall ? 0 : rand(30.0..90.0)
      launch(@dust, x, y, Math.cos(angle) * speed, fall ? rand(30.0..50.0) : Math.sin(angle) * speed, rand(0.8..1.4))
    end
  end

  def snore(x, y)
    launch(@zees, x, y, 8, -22, 2.4)
  end

  def float_motes(dt)
    [[@dust, 0], [@quavers, 8], [@zees, 8]].each do |pool, wobble|
      pool.each do |mote|
        next if mote.age >= mote.life

        mote.age += dt
        mote.age = mote.life if wobble > 0 && mote.y < 6 # a slot or text can't go above the window
        next mote.art.hide if mote.age >= mote.life

        mote.x += mote.vx * dt
        mote.y += mote.vy * dt
        mote.vx *= 0.97
        fade = 1 - mote.age / mote.life
        mote.art.move(px(mote.x + Math.sin(mote.age * 3) * wobble), px(mote.y))
        mote.art.style(fill: rgb(255, 240, 190, fade.round(2))) if pool.equal?(@dust)
        mote.art.style(stroke: rgb(230, 228, 255, (0.9 * fade).round(2))) if pool.equal?(@zees)
      end
    end
  end

  # ---------------------------------------------------------------- shooting stars

  def shooting_star
    return if @shooting

    busy
    @shooting = { x: rand(420.0..900.0), y: rand(30.0..110.0), age: 0.0 }
    %w[a6 g6 e6].each_with_index { |note, i| timer(0.05 + i * 0.18) { sound :twinkle, note } }
  end

  # A shooting star is a bright head and a tail that tapers behind it, all
  # sliding down the sky together and fading out.
  def streak(dt)
    return unless @shooting

    s = @shooting
    s[:age] += dt
    fade = [1 - s[:age] / 1.6, 0].max
    at = ->(back) { [(s[:x] - 300 * [s[:age] - back, 0].max).round(1), (s[:y] + 140 * [s[:age] - back, 0].max).round(1)] }
    x, y = at.(0)
    @meteor[:head].style(left: x, top: y, fill: rgb(255, 252, 235, fade.round(2)), hidden: fade <= 0)
    @meteor[:glow].style(left: x, top: y, fill: rgb(255, 240, 200, (0.25 * fade).round(2)), hidden: fade <= 0)
    @meteor[:tail].each_with_index do |line, i|
      (x1, y1), (x2, y2) = at.(i * 0.03), at.((i + 1) * 0.03)
      line.style(left: x1, top: y1, x2: x2, y2: y2, stroke: rgb(255, 248, 225, (fade * (1 - i / 8.0)).round(2)), hidden: fade <= 0)
    end
    @shooting = nil if s[:age] >= 1.6
  end

  def meteor
    nostroke
    glow = oval 0, 0, 18, center: true, fill: rgb(255, 240, 200, 0), hidden: true
    head = oval 0, 0, 6, center: true, fill: rgb(255, 252, 235, 0), hidden: true
    cap :curve
    tail = Array.new(8) { |i| line 0, 0, 0, 0, strokewidth: 3.4 - i * 0.35, stroke: rgb(255, 248, 225, 0), hidden: true }
    { glow: glow, head: head, tail: tail }
  end

  # ---------------------------------------------------------------- the buttons

  def music_button
    nostroke
    @music_glow = [96, 72].map { |d| oval 74, 74, d, center: true, fill: rgb(255, 214, 110, 0.08) }
    transform :center
    fill "#fff2b8".."#ffc94d"
    stroke rgb(255, 250, 220, 0.8)
    strokewidth 2
    star 74, 74, 5, 40, 19
    nostroke
    fill "#2a2360"
    @play_icon = shape { move_to 68, 64; line_to 68, 84; line_to 84, 74; line_to 68, 64 }
    @pause_icon = [rect(66, 65, 5, 18, curve: 2), rect(76, 65, 5, 18, curve: 2)]
    @pause_icon.each(&:hide)
    @music_pulse = 0.0
  end

  def speaker_button
    nostroke
    fill rgb(255, 255, 255, 0.1)
    stroke rgb(255, 255, 255, 0.22)
    strokewidth 2
    oval 170, 74, 64, center: true
    nostroke
    fill "#e9e4ff"
    rect 154, 67, 9, 14, curve: 2
    shape { move_to 160, 67; line_to 172, 57; line_to 172, 91; line_to 160, 81 }
    nofill
    stroke "#e9e4ff"
    strokewidth 3
    cap :curve
    @waves = [[178, 8], [183, 15]].map do |x, r|
      shape { move_to x, 74 - r; curve_to x + r * 0.7, 74 - r * 0.6, x + r * 0.7, 74 + r * 0.6, x, 74 + r }
    end
    @hush = [line(178, 68, 190, 80), line(190, 68, 178, 80)]
    @hush.each(&:hide)
  end

  def toggle_sound
    @sounds.muted = !@sounds.muted
    @waves.each { |wave| wave.hidden = @sounds.muted }
    @hush.each { |line| line.hidden = !@sounds.muted }
    sound :tick, "g5" unless @sounds.muted
  end

  # ---------------------------------------------------------------- the lullaby

  def toggle_music
    @music_on ? stop_music : start_music
  end

  def start_music
    return if @music_on

    @music_on = true
    @play_icon.hide
    @pause_icon.each(&:show)
    next_note
  end

  def stop_music
    @music_on = false
    @music_timer&.remove
    @music_timer = nil
    @pause_icon.each(&:hide)
    @play_icon.show
  end

  # One note of the lullaby, and a timer for the next. On its last time through
  # the music box winds down: the final notes come slower and slower, then stop.
  def next_note
    return unless @music_on

    note, beats = LULLABY[@note]
    softer = 1 - 0.45 * ease(@sleepy)
    sound :tine, BASS[@beat / 3 % BASS.size], 0.5 * softer if @beat % 3 == 0
    sound :tine, note, 0.9 * softer
    launch(@quavers, 62 + rand(-10.0..10.0), 36, rand(-6.0..10.0), -26, 2.6) if @beat % 3 == 0
    @music_pulse = 1.0
    @beat += beats
    @note += 1
    winding = @plays == PLAYS - 1 ? [@note - (LULLABY.size - 6), 0].max : 0
    if @note == LULLABY.size
      @note = @beat = 0
      @plays += 1
    end
    if @plays == PLAYS
      @plays = 0
      @music_timer = timer(beats * BEAT * 2) { stop_music }
    else
      @music_timer = timer(beats * BEAT * (1 + 0.22 * winding)) { next_note }
    end
  end

  def pulse_button(dt)
    return if @music_pulse <= 0

    @music_pulse = [@music_pulse - dt * 1.5, 0].max
    @music_glow.each_with_index do |glow, i|
      d = ([96, 72][i] + 18 * @music_pulse).round
      glow.style(width: d, height: d, fill: rgb(255, 214, 110, (0.08 + 0.12 * @music_pulse).round(3)))
    end
  end

  # ---------------------------------------------------------------- for grown-ups

  # Holding Escape for two seconds closes the window. A key held down repeats,
  # so the presses keep coming; a gap longer than a moment starts the count again.
  def grown_ups_corner
    stack(left: 40, top: H - 33, width: 180, height: 24) do
      para "hold esc to leave", font: ROUND, size: 12, stroke: rgb(220, 215, 255, 0.4), margin: 0
    end
    nostroke
    @hold_dots = Array.new(12) do |i|
      a = -Math::PI / 2 + i * Math::PI / 6
      oval 24 + 8 * Math.cos(a), H - 24 + 8 * Math.sin(a), 3.4, center: true, fill: rgb(220, 215, 255, 0.25)
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
      @hold_dots.each_with_index { |dot, i| dot.fill = i < lit ? rgb(255, 236, 170, 0.9) : rgb(220, 215, 255, 0.25) }
    end
    close if held >= 1
  end

  # ---------------------------------------------------------------- what taps and keys do

  def sound(voice, note, volume = 1.0)
    @sounds.play(voice, note, volume * (1 - 0.3 * ease(@sleepy)))
  end

  # Any tap or key wakes the sky a little.
  def wake
    @sleepy = [@sleepy - 0.02, 0].max
    played
  end

  def tapped(x, y)
    wake
    return toggle_music if Math.hypot(x - 74, y - 74) < 44
    return toggle_sound if Math.hypot(x - 170, y - 74) < 34
    return turn_moon if Math.hypot(x - MOON_X, y - MOON_Y) < MOON_R + 10

    spot = (@stars + @new_stars.select { |s| s.life > 0 }).min_by { |s| Math.hypot(s.x - x, s.y - y) }
    return sing(spot) if Math.hypot(spot.x - x, spot.y - y) < 32

    cloud = cloud_at(x, y)
    return poke_cloud(cloud) if cloud

    sheep = sheep_at(x, y)
    return hop(sheep) if sheep

    left, top, right, bottom = @cottage_box
    if x.between?(left, right) && y.between?(top, bottom)
      light_window(!@window_on)
      return sound(:tick, "c5")
    end
    return rise_from(x, y) if y > far_hill(x)

    new_star(x, y)
  end

  def pressed(key)
    wake
    case key
    when " " then @shooting ? sing(@stars.sample) : shooting_star
    when "\n" then turn_moon
    when :tab then hop(@sheep.sample)
    when :up, :down, :left, :right then rise_from(*meadow_spot)
    else sing(@stars[key.to_s.sum % @stars.size])
    end
  end

  # ---------------------------------------------------------------- slowly, the sky softens

  def soften(dt)
    @sleepy = [@sleepy + dt / SOFTEN_AFTER, 1.0].min
    step = (@sleepy * 60).round
    return if step == @soft_step

    @soft_step = step
    k = ease(@sleepy)
    @sky_veil.style(fill: rgb(4, 6, 24, (0.5 * k).round(3)), hidden: k < 0.01)
    @ground_veil.style(fill: rgb(4, 6, 24, (0.4 * k).round(3)), hidden: k < 0.01)
    @clouds.each do |cloud|
      alpha = cloud.alpha * (1 - 0.55 * k)
      cloud.art.fill = rgb(236, 232, 255, alpha.round(3))..rgb(170, 168, 232, (alpha * 0.55).round(3))
    end
    return unless k > 0.8 && !@lights_out

    @lights_out = true # once, so a tap can switch it back on
    light_window(false)
  end

  # ---------------------------------------------------------------- every frame

  def tick(dt)
    @clock += dt
    soften(dt)
    twinkle
    spin_moon
    show_face
    ripple(dt)
    drift_clouds(dt)
    bounce_sheep(dt)
    flutter(dt)
    float_motes(dt)
    streak(dt)
    pulse_button(dt)
    watch_escape
    now_and_then
  end

  # A snore from the moon or a sheep when it is late, and a shooting star now and then.
  def now_and_then
    if @clock >= @next_snore
      @next_snore = @clock + 2
      sheep = @sheep.sample
      snore(MOON_X + 40, MOON_Y - 60) if @sleepy > 0.65 && rand < 0.5
      snore(sheep.x + 104, sheep.y + 2) if @sleepy > 0.5 && !sheep.hop
    end
    return if @clock < @next_meteor

    @next_meteor = @clock + rand(30.0..45.0)
    shooting_star
  end

  # Anything that moves quickly keeps the sky at a full thirty frames a second
  # for a while. Otherwise every other frame is plenty for drifting clouds and
  # fireflies, and kinder to a computer that might be left on all night.
  def busy
    @busy_until = @clock + 4
  end

  def played
    @played_at = @clock
    busy
  end

  # Thirty frames a second while anything is quick; fifteen when it is quiet;
  # ten once the sky has gone to sleep and nobody is playing.
  def every_nth_frame
    return 1 if @clock <= @busy_until

    calm? ? 3 : 2
  end

  # Nobody has played for a while: fewer things move at once, which lets the
  # window repaint just the little places that changed.
  def quiet?
    @clock - @played_at > 15
  end

  # The sky is asleep and nobody is playing: as little as possible moves, so a
  # night light left on all night costs the computer very little.
  def calm?
    @sleepy >= 0.95 && quiet?
  end

  # ---------------------------------------------------------------- building it

  @sounds = Sounds.new
  @clock = 0.0
  @sleepy = 0.0
  @phase = @phase_to = 4 # in eighths of the way round: 4 is a full moon
  @startled_until = 0.0
  @moved_at = -9.0
  @window_on = true
  @music_on = false
  @note = @beat = @plays = 0
  @busy_until = 4.0
  @twinkle_turn = 0
  @glow_turn = 0
  @played_at = 0.0
  @last_frame = 0
  @next_snore = 2.0
  @next_meteor = 20.0

  sky
  @stars = place_stars
  draw_stars(@stars)
  @new_stars = spare_stars
  @meteor = meteor
  nostroke
  @sky_veil = rect 0, 0, W, H, fill: rgb(4, 6, 24, 0), hidden: true
  moon
  @clouds = clouds
  hills
  @sheep = flock
  nostroke
  fill rgb(4, 6, 24, 0)
  @ground_veil = hill { |x| far_hill(x) }
  @ground_veil.hide
  @meadow = stack(left: 0, top: 0, width: W, height: H) do
    @fireflies = Array.new(14) { new_firefly(*meadow_spot) }
  end
  motes
  music_button
  speaker_button
  grown_ups_corner

  click { |_button, x, y| tapped(x, y) }
  motion do |x, y|
    @pointer = [x, y]
    @moved_at = @clock
    played
    look_at(x, y)
    if @clock - (@dusted_at || -1) > 0.06
      @dusted_at = @clock
      launch(@dust, x + rand(-6.0..6.0), y + rand(-6.0..6.0), rand(-10.0..10.0), rand(10.0..30.0), 0.9)
    end
  end
  leave { @pointer = nil }
  keypress do |key|
    if key == :escape
      hold_escape
    else
      @escape_since = nil
      pressed(key)
    end
  end

  animate(FPS) do |n|
    next unless (n - @last_frame) >= every_nth_frame

    tick((n - @last_frame) / FPS.to_f)
    @last_frame = n
  end
  timer(1.2) { start_music }
end
