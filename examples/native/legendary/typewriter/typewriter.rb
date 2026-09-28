# Typewriter: a little Italian portable, mint green, ready for a letter.
#
# Type on your keyboard or click the keys. The carriage moves under the type
# as you go, Return sends it home with a zip and a ding, and the paper rolls
# up a line. Backspace takes a letter back with the correction tape. Switch
# the ribbon to red for the bits that matter, and Save page writes it all to
# a text file in Documents/Typewriter.
#
# The clack comes from _why's bloops gem when it is installed, and otherwise
# from little WAV files the app writes once and plays with afplay.

require "fileutils"
require "tmpdir"
begin
  require "bloops"
rescue LoadError
  # no bloops gem: the WAV files do the clacking
end

COLS, LINES = 40, 24 # characters on a line, lines on a page
CHAR_W, LINE_H = 8.4, 22 # a letter of 14 px monospace is 0.6 of its size wide
STRIKE_X, STRIKE_Y = 360, 284 # where the next letter lands
MARGIN, PAPER_TOP = 24, 40 # the paper's margins round the text
PAPER_W = (MARGIN * 2 + COLS * CHAR_W).ceil
CARRIAGE_TOP = 244 # the carriage's slot; the platen runs just under the line being typed
INKS = { "black" => "#2a2624", "red" => "#b3342b" }
TYPE = "Courier New, Courier, monospace"
KEY_ROWS = ["1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm,."]
SAVE_DIR = File.join(Dir.home, "Documents", "Typewriter")

# The machine's voice: a few sounds, each written once as a WAV file and
# played in the background with afplay.
class Clatter
  RATE = 22_050

  attr_reader :last_file, :player

  def initialize
    @dir = Dir.mktmpdir("typewriter")
    @noise = Random.new(3)
    @files = {}
  end

  def play(name)
    @last_file = @files[name] ||= write(name, samples(name))
    @player = Process.detach(spawn("afplay", @last_file, out: File::NULL, err: File::NULL))
  rescue SystemCallError
    # no afplay here (not a Mac): type in silence
  end

  def samples(name)
    case name
    when :key1 then strike(170, 2600, 0.9)
    when :key2 then strike(150, 2300, 1.0)
    when :key3 then strike(190, 2900, 0.85)
    when :space then strike(110, 1400, 0.6)
    when :tick then strike(240, 3200, 0.35)
    when :stop then strike(80, 900, 0.9)
    when :return then carriage_return
    end
  end

  private

  # `seconds` of sound, one sample for each moment t.
  def sound(seconds, &wave)
    Array.new((RATE * seconds).round) { |i| wave.call(i.fdiv(RATE)) }
  end

  def noise
    @noise.rand * 2 - 1
  end

  def ring(hz, t)
    Math.sin(2 * Math::PI * hz * t)
  end

  # A key: the typebar cracks against the platen over a wooden knock and a
  # bright click, then taps once more, softly, as it falls back.
  def strike(knock, click, loud)
    sound(0.1) do |t|
      back = t - 0.012
      loud * (0.7 * noise * Math.exp(-t * 170) + 0.5 * ring(knock, t) * Math.exp(-t * 50) +
        0.35 * ring(click, t) * Math.exp(-t * 125) + (back > 0 ? 0.25 * noise * Math.exp(-back * 300) : 0))
    end
  end

  # Home again: the ratchet clicks, the carriage hisses across, thumps
  # against the stop, and the bell rings.
  def carriage_return
    sound(1.3) do |t|
      clicks = [0.0, 0.05].sum { |at| t < at ? 0 : 0.5 * ring(3000, t - at) * Math.exp(-(t - at) * 300) }
      hiss = t.between?(0.05, 0.33) ? 0.1 * noise * Math.sin(Math::PI * (t - 0.05) / 0.28) : 0
      thump = t < 0.33 ? 0 : 0.8 * ring(90, t - 0.33) * Math.exp(-(t - 0.33) * 30)
      bell = t < 0.35 ? 0 : [[1760, 0.3, 3], [4858, 0.13, 6], [9504, 0.05, 10]].sum do |hz, amp, fade|
        amp * ring(hz, t - 0.35) * Math.exp(-(t - 0.35) * fade)
      end
      clicks + hiss + thump + bell
    end
  end

  # A WAV file is a 44-byte header, then every sample as a 16-bit number.
  def write(name, samples)
    data = samples.map { |sample| (Math.tanh(sample) * 32_767).round }.pack("s<*")
    header = ["RIFF", 36 + data.bytesize, "WAVE", "fmt ", 16, 1, 1, RATE, RATE * 2, 2, 16, "data", data.bytesize]
    path = File.join(@dir, "#{name}.wav")
    File.binwrite(path, header.pack("a4Va4a4VvvVVvva4V") + data)
    path
  end
end

# The same sounds on _why's bloopsaphone, when the gem is here.
class BloopsClatter
  def initialize
    @song = Bloops.new
    @song.tempo = 400
    @key = sound(Bloops::NOISE, volume: 0.5, sustain: 0.0, decay: 0.08, hpf: 0.3)
    @bell = sound(Bloops::SINE, volume: 0.4, sustain: 0.1, decay: 0.6)
  end

  def play(name)
    @song.clear
    if name == :return
      @song.tune(@key, "16c3 16c3 4 16a1")
      @song.tune(@bell, "4 4 a6")
    else
      @song.tune(@key, { space: "c3", stop: "a1", tick: "c6" }.fetch(name, "c5"))
    end
    @song.play
  end

  private

  def sound(type, **settings)
    Bloops.sound(type).tap { |sound| settings.each { |name, value| sound.send("#{name}=", value) } }
  end
end

Shoes.app(title: "Typewriter", width: 720, height: 680, resizable: false) do
  # ---- the page ----

  def text
    @lines.map { |runs| runs.sum("") { |_ink, letters| letters } }.join("\n").rstrip + "\n"
  end

  def column
    @lines[@line].sum { |_ink, letters| letters.size }
  end

  # A line is a list of [ink, letters] runs, so red and black can share it.
  def show_line(index)
    runs = @lines[index].map { |ink, letters| span(letters, stroke: INKS[ink]) }
    @rows[index].replace(*runs)
  end

  def type(letter)
    return clunk if @full
    return clunk if column >= COLS

    runs = @lines[@line]
    runs << [@ink, +""] unless runs.last && runs.last[0] == @ink
    runs.last[1] << letter
    show_line(@line)
    sink_key(letter)
    @voice.play(letter == " " ? :space : %i[key1 key2 key3].sample)
    move_carriage
    @hint.hide
  end

  def clunk
    @voice.play(:stop)
    tell(@full ? "The page is full. Save it, or put in a new sheet." : "The carriage is at the margin. Press Return.")
  end

  # The correction tape lifts the last letter off the page.
  def backspace
    runs = @lines[@line]
    return if runs.empty?

    runs.last[1].chop!
    runs.pop if runs.last[1].empty?
    show_line(@line)
    @voice.play(:tick)
    move_carriage
  end

  def carriage_return
    @voice.play(:return)
    if @line == LINES - 1
      @full = true
      tell "The page is full. Save it, or put in a new sheet."
    else
      @line += 1
    end
    move_carriage
  end

  def tab
    (8 - column % 8).times { type(" ") } if column < COLS
  end

  # ---- the carriage ----

  # The paper and the platen glide to where the next letter will land.
  def move_carriage
    @to = [STRIKE_X - MARGIN - column * CHAR_W, STRIKE_Y - PAPER_TOP - @line * LINE_H]
    @glide.start
  end

  def glide
    @at = @at.zip(@to).map { |now, to| (to - now).abs < 0.5 ? to : now + (to - now) * 0.45 }
    x, y = @at
    @paper.move(x.round, y.round)
    @carriage.move(x.round - 70, CARRIAGE_TOP)
    @glide.stop if @at == @to
  end

  # The key for a letter dips and darkens for a moment, as if a finger struck it.
  def sink_key(letter)
    key = @keys[letter.downcase] or return
    key[:key].top = key[:top] + 3
    key[:cap].fill = "#44434a"
    timer(0.09) do
      key[:key].top = key[:top]
      key[:cap].fill = "#26252a"
    end
  end

  # ---- the ribbon, saving, a fresh sheet ----

  def ribbon(ink)
    @ink = ink
    @ribbon_marks.each { |name, ring| ring.hidden = name != ink }
    tell(ink == "red" ? "Red ribbon: for the words that matter." : "Black ribbon.")
  end

  def save_page
    FileUtils.mkdir_p(SAVE_DIR)
    @saved_to = File.join(SAVE_DIR, "Page #{Time.now.strftime("%Y-%m-%d %H.%M.%S")}.txt")
    File.write(@saved_to, text)
    tell "Saved to #{@saved_to.sub(Dir.home, "~")}"
  rescue SystemCallError => e
    tell "The page could not be saved: #{e.message}"
  end

  def new_sheet
    @lines = Array.new(LINES) { [] }
    @rows.each_index { |index| show_line(index) }
    @line = 0
    @full = false
    @at = [@at[0], STRIKE_Y + 60] # the fresh sheet feeds up from behind the platen
    @voice.play(:return)
    move_carriage
    tell "A fresh sheet."
  end

  def tell(words)
    @note.replace words
  end

  # A chrome button on the body with a label on it.
  def body_button(left, top, label, &on_click)
    button = stack(left: left, top: top, width: 108, height: 32, cursor: :hand_cursor) do
      background "#f4f5f2".."#c9cdc8", curve: 16
      border rgb(40, 60, 50, 0.3), curve: 16, strokewidth: 2
      para label, align: "center", size: 12, weight: "semibold", stroke: "#34403a", margin_top: 8
    end
    button.click(&on_click)
  end

  # ---- building it ----

  @voice = defined?(Bloops) ? BloopsClatter.new : Clatter.new
  @lines = Array.new(LINES) { [] }
  @line = 0
  @ink = "black"
  @full = false

  # a dark desk under a warm lamp: light fading out from a centre, in circles
  background "#3a2b23".."#1f1712"
  nostroke
  fill rgb(255, 180, 120, 0.016)
  18.times { |i| oval 330, 30, 640 * (1 - i / 18.0), center: true }
  @hint = stack left: 0, top: 120, width: 720 do
    para "Start typing.", align: "center", size: 22, family: "Iowan Old Style, Georgia, serif",
      emphasis: "italic", stroke: rgb(255, 236, 214, 0.6)
  end

  # the paper, one line of type after another
  @at = [STRIKE_X - MARGIN, STRIKE_Y - PAPER_TOP]
  @to = @at.dup
  @paper = stack left: @at[0], top: @at[1], width: PAPER_W + 4, height: PAPER_TOP * 2 + LINES * LINE_H do
    nostroke
    rect 3, 2, PAPER_W, PAPER_TOP * 2 + LINES * LINE_H, fill: rgb(0, 0, 0, 0.28) # its shadow on the desk
    rect 0, 0, PAPER_W, PAPER_TOP * 2 + LINES * LINE_H, fill: "#fffdf6".."#f1ebdc"
    @rows = Array.new(LINES) do |index|
      para "", left: MARGIN, top: PAPER_TOP + index * LINE_H, size: 14, family: TYPE, margin: 0, wrap: "trim"
    end
  end

  # the carriage: the black rubber platen, its knobs, and the return lever
  @carriage = stack left: @at[0] - 70, top: CARRIAGE_TOP, width: PAPER_W + 140, height: 110 do
    nostroke
    fill "#4c4c52".."#141416"
    rect 50, 62, PAPER_W + 40, 38, curve: 8
    fill rgb(255, 255, 255, 0.14)
    rect 54, 66, PAPER_W + 32, 3, curve: 1.5
    [26, PAPER_W + 114].each do |x|
      fill "#e9ebe8".."#9ea3a0"
      oval x, 81, 44, center: true
      fill "#5a5e5c"
      oval x, 81, 14, center: true
    end
    stroke "#dfe2df"
    strokewidth 6
    cap :curve
    @lever = line 34, 70, 8, 30, cursor: :hand_cursor
    nostroke
    fill "#f4f5f2"
    @lever_tip = oval 8, 30, 14, center: true, cursor: :hand_cursor
  end
  [@lever, @lever_tip].each { |part| part.click { carriage_return } }

  # the body, the type guide, the name plate
  nostroke
  fill "#9cc4b3".."#6e9888"
  rect 20, 344, 680, 360, curve: 30
  fill rgb(255, 255, 255, 0.25)
  rect 44, 348, 632, 3, curve: 1.5
  fill "#dfe3df".."#aab1ad"
  shape do
    move_to STRIKE_X - 20, 346
    line_to STRIKE_X - 10, 306
    line_to STRIKE_X - 3, 306
    line_to STRIKE_X, 311
    line_to STRIKE_X + 3, 306
    line_to STRIKE_X + 10, 306
    line_to STRIKE_X + 20, 346
    line_to STRIKE_X - 20, 346
  end
  fill rgb(40, 60, 50, 0.22)
  rect 150, 392, 420, 222, curve: 22
  stack left: 260, top: 358, width: 200 do
    para "scarpetta 32", align: "center", size: 13, family: "Iowan Old Style, Georgia, serif",
      emphasis: "italic", weight: "bold", stroke: "#f6f7f2", kerning: 1, margin: 0
  end

  # the keys: dark caps in chrome rings, a row at a time, each row a little further right.
  # Each key is a small slot holding its cap and its letter, so a click anywhere on it types.
  @keys = {}
  KEY_ROWS.each_with_index do |row, r|
    row.each_char.with_index do |letter, i|
      x = 172 + [0, 12, 24, 36][r] + i * 42
      y = 420 + r * 44
      cap = nil
      key = stack left: x - 17, top: y - 17, width: 34, height: 37, cursor: :hand_cursor do
        stroke "#d4d8d5"
        strokewidth 3
        cap = oval 17, 17, 31, center: true, fill: "#26252a"
        para letter.upcase, align: "center", size: 12, weight: "bold", stroke: "#f2f2ee", margin_top: 10
      end
      key.click { type(letter) }
      @keys[letter] = { key: key, cap: cap, top: y - 17 }
    end
  end
  nostroke
  fill "#e6e9e6".."#b3b9b5"
  space = rect 230, 584, 260, 20, curve: 10, cursor: :hand_cursor
  space.click { type(" ") }

  # left of the keys, the ribbon switch; right of them, the page
  stack left: 44, top: 424, width: 90 do
    para "RIBBON", align: "center", size: 10, weight: "bold", kerning: 2, stroke: "#29443a", margin: 0
  end
  @ribbon_marks = {}
  { "black" => 70, "red" => 108 }.each do |ink, x|
    nofill
    stroke "#f6f7f2"
    strokewidth 2
    @ribbon_marks[ink] = oval x, 460, 30, center: true, hidden: ink != "black"
    nostroke
    dot = oval x, 460, 20, center: true, fill: INKS[ink], cursor: :hand_cursor
    dot.click { ribbon(ink) }
  end
  body_button(588, 424, "Save page") { save_page }
  body_button(588, 466, "New sheet") { new_sheet }

  stack left: 40, top: 640, width: 640 do
    @note = para "", align: "center", size: 12, stroke: "#20382f", margin: 0
  end

  keypress do |key|
    case key
    when "\n" then carriage_return
    when :backspace then backspace
    when :tab then tab
    when :alt_s then save_page
    when :alt_n then new_sheet
    when String then type(key) if key.size == 1 && key.ord >= 32
    end
  end

  @glide = animate(60) { glide }
  tell "Type on your keyboard, or click the keys. Return sends the carriage home."
end
