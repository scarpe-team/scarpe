# Bloop Sequencer: sixteen steps, four voices, one small drum machine.
#
# Click the pads to switch them on, then press Play or the space bar. Up and
# down change the tempo, left and right change the pattern. The bloop row sings
# a pentatonic tune, so whatever you switch on sounds right. Or roll the dice.
#
# The sound comes from _why's bloops gem when it is installed (gem install bloops,
# which needs PortAudio), and otherwise from small WAV files the app writes once
# and plays with afplay.

require "tmpdir"
begin
  require "bloops"
rescue LoadError
  # no bloops gem: the WAV files do the singing
end

STEPS = 16
VOICES = %i[kick snare hat bloop]
COLORS = { kick: [255, 107, 107], snare: [255, 196, 87], hat: [72, 219, 170], bloop: [124, 156, 255] }
TUNE = %w[a4 c5 e5 g5 a5 g5 e5 d5 c5 d5 e5 g5 e5 d5 c5 e5] # the bloop row's note on each step
PATTERNS = {
  "Four on the floor" => %w[x...x...x...x... ....x.......x... ..x...x...x...x. x..x..x...x.x...],
  "Boom bap" => %w[x......x..x..... ....x.......x... x.x.x.x.x.x.x.xx ..x.......x.x...],
  "Bossa bloop" => %w[x..x..x.x..x..x. ..x..x....x..x.. xx.xxx.xxx.xxx.x x.x..x.x..x..x.x],
  "Chiptune march" => %w[x.x.x.x.x.x.x.x. ....x.......x.xx .x.x.x.x.x.x.x.x xxxxxxxxxxxxxxxx],
  "Empty page" => %w[................ ................ ................ ................],
}
INK = "#f3f0ff"
MUTED = "#8f89b8"
DIGITS = "Helvetica Neue, sans-serif" # its figures are all one width, so the tempo never wobbles

# A very small synthesizer. Each voice is a list of samples worked out once;
# a step mixes the voices it needs into a WAV file, also once, and afplay
# plays that file in the background while the app carries on.
class WavSynth
  RATE = 22_050
  NOTE_NAMES = %w[c c# d d# e f f# g g# a a# b]

  attr_reader :last_file, :player

  def initialize
    @dir = Dir.mktmpdir("bloop-sequencer")
    @noise = Random.new(1)
    @samples = {}
    @files = {}
  end

  def play(voices, note)
    name = voices.map { |voice| voice == :bloop ? "bloop-#{note}" : voice }.join("+")
    @last_file = @files[name] ||= write(name, mix(voices.map { |voice| samples(voice, note) }))
    @player = Process.detach(spawn("afplay", @last_file, out: File::NULL, err: File::NULL))
  rescue SystemCallError
    # no afplay here (not a Mac): stay quiet rather than stop the music
  end

  # One voice's samples at one note, worked out the first time they are asked for.
  def samples(voice, note)
    @samples[[voice, voice == :bloop ? note : nil]] ||= send(voice, note)
  end

  private

  # `seconds` of sound, one sample for each moment t; the last hundredth of a second fades out.
  def sound(seconds)
    (0...(RATE * seconds).round).map do |i|
      t = i.fdiv(RATE)
      yield(t) * [(seconds - t) * 100, 1].min
    end
  end

  # a low hum that drops in pitch as it fades
  def kick(_note)
    phase = 0.0
    sound(0.4) do |t|
      phase += (46 + 120 * Math.exp(-t * 28)) / RATE
      0.9 * Math.sin(2 * Math::PI * phase) * Math.exp(-t * 8)
    end
  end

  # a crack of noise over a short tone
  def snare(_note)
    sound(0.24) do |t|
      0.55 * noise * Math.exp(-t * 20) + 0.45 * Math.sin(2 * Math::PI * 190 * t) * Math.exp(-t * 28)
    end
  end

  # a tick of bright noise: only the change from one sample to the next, which keeps the high notes
  def hat(_note)
    last = 0.0
    sound(0.08) do |t|
      now = noise
      bright, last = now - last, now
      0.25 * bright * Math.exp(-t * 60)
    end
  end

  # a softened square wave that swoops up into its note
  def bloop(note)
    hz = frequency(note)
    phase = soft = 0.0
    sound(0.3) do |t|
      phase += hz * (1 - 0.3 * Math.exp(-t * 50)) / RATE
      soft += ((phase % 1 < 0.3 ? 1 : -1) - soft) * 0.3
      0.3 * soft * Math.exp(-t * 9) * [t * 300, 1].min
    end
  end

  def noise
    @noise.rand * 2 - 1
  end

  # "a4" is 440 Hz, and each semitone up is the twelfth root of two higher.
  def frequency(note)
    semitones = NOTE_NAMES.index(note[/\D+/]) + 12 * (note[/\d+/].to_i + 1) - 69
    440 * 2**(semitones / 12.0)
  end

  # Voices add up; tanh rounds off the loudest moments instead of clipping them.
  def mix(parts)
    out = Array.new(parts.map(&:size).max, 0.0)
    parts.each { |part| part.each_with_index { |sample, i| out[i] += sample } }
    out.map { |sample| Math.tanh(sample * 0.85) }
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

# The same four voices on _why's bloopsaphone, when the gem is here.
class BloopsSynth
  NOTES = { kick: "c3", snare: "d4", hat: "c6" } # the bloop row brings its own note

  def initialize
    @songs = Array.new(4) { Bloops.new.tap { |song| song.tempo = 480 } }
    @voices = {
      kick: sound(Bloops::SINE, volume: 0.9, punch: 0.4, sustain: 0.06, decay: 0.3, slide: -0.5),
      snare: sound(Bloops::NOISE, volume: 0.6, sustain: 0.02, decay: 0.25, hpf: 0.35),
      hat: sound(Bloops::NOISE, volume: 0.35, sustain: 0.01, decay: 0.07, hpf: 0.8),
      bloop: sound(Bloops::SQUARE, volume: 0.45, punch: 0.3, sustain: 0.06, decay: 0.25, square: 0.3),
    }
  end

  # The songs take turns, so one step's long notes ring on under the next.
  def play(voices, note)
    song = @songs.rotate!.first
    song.clear
    voices.each { |voice| song.tune(@voices[voice], NOTES.fetch(voice, note)) }
    song.play
  end

  private

  def sound(type, **settings)
    Bloops.sound(type).tap { |sound| settings.each { |name, value| sound.send("#{name}=", value) } }
  end
end

Shoes.app(title: "Bloop Sequencer", width: 720, height: 590, resizable: false) do
  def pad_left(step)
    104 + step * 36 + step / 4 * 8
  end

  def row_top(row)
    242 + row * 52
  end

  def orb_x(row)
    108 + row * 168
  end

  # The pad under a point in the window, as [row, step], or nil.
  def pad_at(x, y)
    row = ((y - row_top(0)) / 52).floor
    step = (0...STEPS).find { |i| x.between?(pad_left(i), pad_left(i) + 30) }
    [row, step] if step && row.between?(0, VOICES.size - 1) && y - row_top(row) <= 40
  end

  # A colour as rgb, `amount` of the way to white.
  def lighter(color, amount)
    rgb(*color.map { |part| (part + (255 - part) * amount).round })
  end

  def glass(alpha)
    rgb(255, 255, 255, alpha)
  end

  # Lit pads wear their voice's colour, the rest are smoked glass, a shade
  # lighter on the beat. The pad under the pointer and pads just played glow.
  def pad_fill(row, step, heat = 0.0)
    hover = @hover == [row, step] ? 0.2 : 0.0
    return lighter(COLORS[VOICES[row]], [0.6 * heat + hover, 1.0].min) if @on[row][step]

    glass((step % 4 == 0 ? 0.085 : 0.055) + hover * 0.4)
  end

  def paint_pad(row, step)
    @pads[row][step].fill = pad_fill(row, step, @flashes.fetch([row, step], 0.0))
  end

  def load_pattern(name)
    @pattern = name
    @pattern_name.replace name
    @on = PATTERNS[name].map { |line| line.chars.map { |mark| mark == "x" } }
    VOICES.each_index { |row| STEPS.times { |step| paint_pad(row, step) } }
  end

  def next_pattern(by)
    names = PATTERNS.keys
    load_pattern names[(names.index(@pattern) + by) % names.size]
  end

  # Switching a pad on lets you hear it at once. Pressing one starts a stroke:
  # drag across more pads to switch them the same way.
  def press_pad(row, step)
    toggle(row, step)
    @painting = @on[row][step]
  end

  def toggle(row, step)
    @on[row][step] = !@on[row][step]
    paint_pad(row, step)
    sound([VOICES[row]], step) if @on[row][step]
  end

  # Musical dice: the kick keeps the downbeat, the snare the backbeat,
  # and the rest is chance.
  def roll_dice
    @on = VOICES.map { |voice| Array.new(STEPS) { |step| chance(voice, step) } }
    VOICES.each_index { |row| STEPS.times { |step| paint_pad(row, step) } }
    @pattern_name.replace "Rolled by the dice"
  end

  def chance(voice, step)
    case voice
    when :kick then step == 0 || rand < (step.even? ? 0.3 : 0.1)
    when :snare then step == 4 || step == 12 || rand < 0.08
    when :hat then rand < (step.even? ? 0.8 : 0.3)
    else rand < 0.4
    end
  end

  def sound(voices, step)
    @synth.play(voices, TUNE[step])
    voices.each { |voice| pulse(VOICES.index(voice)) }
  end

  def set_tempo(bpm)
    @bpm = bpm.clamp(60, 200)
    @tempo.replace @bpm.to_s
    run_clock if @playing
  end

  # Four steps to a beat, so a step lasts a quarter of a beat.
  def run_clock
    @clock&.remove
    @clock = every(60.0 / @bpm / 4) { step }
  end

  def play
    @playing = true
    @step = -1
    step
    run_clock
    @play_label.replace "Stop"
    @play_icon.hide
    @stop_icon.show
  end

  def stop
    @playing = false
    @clock&.remove
    @clock = nil
    @play_label.replace "Play"
    @stop_icon.hide
    @play_icon.show
  end

  def step
    @step = (@step + 1) % STEPS
    @column.left = pad_left(@step) - 4
    @marker.left = pad_left(@step) + 9
    rows = VOICES.each_index.select { |row| @on[row][@step] }
    return if rows.empty?

    sound(rows.map { |row| VOICES[row] }, @step)
    rows.each { |row| @flashes[[row, @step]] = 1.0 }
  end

  # An orb swells and sends out a ring each time its voice sounds.
  def pulse(row)
    @glow[row] = 1.0
    ring = @rings[row].rotate!.first
    ring[:age] = 0.0
    @lights.start
  end

  # Sixty times a second: orbs settle, rings spread and fade, lit pads cool down.
  # It stops itself once everything is still.
  def settle
    @orbs.each_with_index do |(halo, core), row|
      glow = @glow[row] *= 0.88
      color = COLORS[VOICES[row]]
      core.style(width: 36 + 12 * glow, height: 36 + 12 * glow, fill: lighter(color, 0.4 * glow))
      halo.style(width: 60 + 26 * glow, height: 60 + 26 * glow, fill: rgb(*color, 0.1 + 0.14 * glow))
    end
    @rings.each_with_index do |rings, row|
      rings.each do |ring|
        next if ring[:age] > 1

        ring[:age] += 1 / 40.0
        size = 44 + 80 * ring[:age]
        ring[:shape].style(width: size, height: size, hidden: ring[:age] > 1,
          stroke: rgb(*COLORS[VOICES[row]], 0.6 * (1 - ring[:age])))
      end
    end
    @flashes.transform_values! { |heat| heat * 0.86 }
    @flashes.each_key { |row, step| paint_pad(row, step) }
    @flashes.delete_if { |_, heat| heat < 0.02 }
    still = @glow.all? { |glow| glow < 0.01 } && @rings.flatten.all? { |ring| ring[:age] > 1 } && @flashes.empty?
    @lights.stop if still && !@playing
  end

  # A rounded button: a background, an icon drawn by the block, and a label.
  # Returns the button and its label. The icon is drawn inside the button, so
  # pressing the icon presses the button.
  def pill(left, width, label, look: glass(0.08), text: INK, indent: 0, &icon)
    words = nil
    button = stack(left: left, top: 490, width: width, height: 46, cursor: :hand_cursor) do
      background look, curve: 23
      nostroke
      icon&.call
      words = para label, align: "center", size: 14, weight: "semibold", stroke: text, margin: [indent, 14, 0, 0]
    end
    [button, words]
  end

  # Five pips on a die, for the Dice button.
  def die(x, y)
    fill glass(0.85)
    rect x, y, 16, 16, curve: 4
    fill "#2a2350"
    [[4, 4], [12, 4], [8, 8], [4, 12], [12, 12]].each { |dx, dy| oval x + dx, y + dy, 3.4, center: true }
  end

  @synth = defined?(Bloops) ? BloopsSynth.new : WavSynth.new
  @bpm = 112
  @playing = false
  @step = -1
  @glow = [0.0] * VOICES.size
  @flashes = {}

  background "#16122c".."#221b45"

  # the name, and the tempo on the right
  nostroke
  VOICES.each_with_index do |voice, i|
    fill rgb(*COLORS[voice])
    rect 28 + i % 2 * 13, 28 + i / 2 * 13, 10, 10, curve: 3
  end
  stack left: 66, top: 22, width: 300 do
    para "Bloop Sequencer", size: 20, weight: "bold", stroke: INK, margin: 0
    para "sixteen steps, four voices, one tune", size: 12, stroke: MUTED, margin: [0, 3, 0, 0]
  end

  { "−" => [528, -4], "+" => [668, 4] }.each do |label, (x, change)|
    button = stack(left: x, top: 26, width: 30, height: 30, cursor: :hand_cursor) do
      background glass(0.08), curve: 15
      para label, align: "center", size: 16, weight: "medium", stroke: INK, margin_top: 5
    end
    button.click { set_tempo(@bpm + change) }
  end
  stack left: 566, top: 18, width: 96 do
    @tempo = para @bpm.to_s, align: "center", size: 26, weight: "bold", family: DIGITS, stroke: INK, margin: 0
    para "BPM", align: "center", size: 10, weight: "semibold", kerning: 2, stroke: MUTED, margin: 0
  end

  # the visualizer: an orb for each voice, and rings that spread when it sounds
  stack left: 24, top: 84, width: 672, height: 132 do
    background glass(0.035), curve: 20
  end
  nofill
  strokewidth 2
  @rings = VOICES.each_index.map do |row|
    Array.new(3) { { age: 2.0, shape: oval(orb_x(row), 150, 44, center: true, hidden: true) } }
  end
  nostroke
  @orbs = VOICES.each_with_index.map do |voice, row|
    halo = oval orb_x(row), 150, 60, center: true, fill: rgb(*COLORS[voice], 0.1)
    core = oval orb_x(row), 150, 36, center: true, fill: rgb(*COLORS[voice])
    [halo, core]
  end

  # the grid: a lit column that follows the playhead, a pad for every step of every voice
  @column = rect pad_left(0) - 4, row_top(0) - 6, 38, 52 * 4 + 2, curve: 10, fill: glass(0.07)
  @pads = VOICES.each_with_index.map do |voice, row|
    stack left: 24, top: row_top(row) + 11, width: 76 do
      para voice.to_s.capitalize, size: 12, weight: "semibold", stroke: rgb(*COLORS[voice]), margin: 0
    end
    Array.new(STEPS) do |step|
      pad = rect pad_left(step), row_top(row), 30, 40, curve: 8, cursor: :hand_cursor
      pad.click { press_pad(row, step) }
      pad.hover { @hover = [row, step]; paint_pad(row, step) }
      pad.leave { @hover = nil; paint_pad(row, step) }
      pad
    end
  end

  # a dot under every step, bigger on the beat, and the playhead's marker
  STEPS.times do |step|
    size = step % 4 == 0 ? 5 : 3
    oval pad_left(step) + 15, row_top(4) + 6, size, center: true, fill: glass(step % 4 == 0 ? 0.35 : 0.18)
  end
  @marker = rect pad_left(0) + 9, row_top(4) - 2, 12, 3, curve: 1.5, fill: glass(0.85)

  # the controls
  play_button, @play_label = pill(24, 128, "Play", look: "#a9bcff".."#c7b3ff", text: "#1d1838") do
    fill "#1d1838"
    @play_icon = shape do
      move_to 28, 15
      line_to 28, 31
      line_to 41, 23
      line_to 28, 15
    end
    @stop_icon = rect 27, 17, 12, 12, curve: 2, hidden: true
  end
  play_button.click { @playing ? stop : play }
  clear_button, = pill(164, 92, "Clear")
  clear_button.click { load_pattern("Empty page") }
  dice_button, = pill(264, 104, "Dice", indent: 22) { die 22, 15 }
  dice_button.click { roll_dice }

  # the pattern: its name, with an arrow each side to step through the others
  name_plate, @pattern_name = pill(460, 184, "")
  name_plate.click { next_pattern(1) }
  { "\u2039" => [408, -1], "\u203A" => [650, 1] }.each do |arrow, (x, by)|
    button, = pill(x, 46, "") do
      para arrow, align: "center", size: 20, weight: "medium", stroke: INK, margin_top: 8
    end
    button.click { next_pattern(by) }
  end
  stack left: 0, top: 552, width: 720 do
    inscription "Space plays and stops. Up and down set the tempo, left and right the pattern. Drag to paint pads.",
      align: "center", stroke: MUTED
  end

  keypress do |key|
    case key
    when " " then @playing ? stop : play
    when :up, "+", "=" then set_tempo(@bpm + 4)
    when :down, "-" then set_tempo(@bpm - 4)
    when :left then next_pattern(-1)
    when :right then next_pattern(1)
    end
  end

  # dragging paints pads the way the first one went; letting go ends the stroke
  motion do |x, y|
    row, step = pad_at(x, y)
    toggle(row, step) if row && !@painting.nil? && @on[row][step] != @painting
  end
  release { @painting = nil }

  @lights = animate(60) { settle }
  load_pattern "Four on the floor"
end
