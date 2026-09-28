# Pixel Pet: a small creature that lives in a pocket-sized egg.
#
# Feed it, play with it, put it to bed, give it a pat. It gets hungry, bored
# and sleepy as time goes by, even while the app is closed, because it
# remembers: its name, its birthday and how it feels are kept in your
# Application Support folder. The first time you open it, there is only an egg.
#
# Its chirps come from _why's bloops gem when it is installed, and otherwise
# from little WAV files the app writes once and plays with afplay.

require "json"
require "fileutils"
require "tmpdir"
begin
  require "bloops"
rescue LoadError
  # no bloops gem: the WAV files do the chirping
end

SAVE_FILE = File.join(Dir.home, "Library", "Application Support", "Pixel Pet", "pet.json")
DOT = 10 # one pixel of the little screen, in window pixels
LCD_X, LCD_Y, LCD_COLS, LCD_ROWS = 130, 150, 26, 20
PET_COL, PET_ROW = 5, 3 # where the pet stands on the screen, in dots
DAY, NIGHT = [223, 233, 207], [47, 52, 82]

# Every picture below is lines of letters, one letter to a dot of the screen.
# This is what each letter is painted with; a full stop is see-through.
PAINT = {
  "o" => [74, 59, 82],    # outline
  "#" => [255, 246, 238], # fur
  "s" => [241, 217, 203], # the shade under its tummy
  "p" => [255, 158, 187], # pink: ears, cheeks and the egg's spots
  "e" => [45, 36, 51],    # eyes
  "w" => [255, 255, 255], # the light in its eyes
  "m" => [138, 40, 70],   # mouth
  "t" => [255, 111, 145], # tongue
  "r" => [239, 71, 111],  # apple
  "g" => [82, 183, 136],  # leaf
  "h" => [255, 93, 143],  # heart
  "y" => [255, 209, 102], # sleepy Zs and the lightning bolt
}

def art(text) = text.lines(chomp: true)

# The pet is its ears, a face that changes with its mood, and its round bottom.
EARS = art(<<~ART)
  ................
  ..oo........oo..
  .o#po......op#o.
  .o#ppo....opp#o.
  .o###oooooo###o.
  o##############o
ART
BODY = art(<<~ART)
  os############so
  .os##########so.
  ..oosssssssssoo.
  ...ooo....ooo...
ART
FACES = {
  content: <<~ART,
    o###we####we###o
    o###ee####ee###o
    o###ee####ee###o
    o#pp########pp#o
    o######mm######o
    o##############o
  ART
  blink: <<~ART,
    o##############o
    o##############o
    o###ee####ee###o
    o#pp########pp#o
    o######mm######o
    o##############o
  ART
  happy: <<~ART,
    o###we####we###o
    o###ee####ee###o
    o###ee####ee###o
    o#pp##m##m##pp#o
    o######mm######o
    o##############o
  ART
  joy: <<~ART,
    o##############o
    o####e####e####o
    o###e#e##e#e###o
    o#pp##m##m##pp#o
    o######mm######o
    o##############o
  ART
  eat: <<~ART,
    o###we####we###o
    o###ee####ee###o
    o###ee####ee###o
    o#pp###mm###pp#o
    o#####mttm#####o
    o######mm######o
  ART
  chew: <<~ART,
    o##############o
    o####e####e####o
    o###e#e##e#e###o
    o#ppp######ppp#o
    o######mm######o
    o##############o
  ART
  sad: <<~ART,
    o###we####we###o
    o###ee####ee###o
    o###ee####ee###o
    o#pp########pp#o
    o######mm######o
    o#####m##m#####o
  ART
  sleepy: <<~ART,
    o##############o
    o###oo####oo###o
    o###ee####ee###o
    o#pp########pp#o
    o######mm######o
    o##############o
  ART
}.transform_values { |face| EARS + art(face) + BODY }
FACES[:asleep] = FACES[:blink]

EGG = art(<<~ART)
  ................
  ......oooo......
  .....o####o.....
  ....o######o....
  ....o#pp###o....
  ...o#pppp###o...
  ...o##pp####o...
  ..o#######pp#o..
  ..o#####pppp#o..
  ..o######pp##o..
  ..o##########o..
  ..o#pp#######o..
  ..os#ppp####so..
  ...os#pp###so...
  ....oossssoo....
  ......oooo......
ART
# Each tap cracks the egg a little further.
CRACKS = [
  EGG,
  EGG.dup.tap { |egg| egg[7], egg[8] = "..o#o#o#o#pp#o..", "..oo#o#o#ppp#o.." },
  EGG.dup.tap { |egg| egg[7], egg[8] = "..o#o#o#o#o#oo..", "..oo#o#o#o#o#o.." },
]

APPLES = [<<~FULL, <<~BITTEN, <<~CORE].map { |apple| art(apple) }
  ..og...
  ...og..
  .oooooo
  orrrwro
  orrrrro
  orrrrro
  .orrro.
  ..ooo..
FULL
  ..og...
  ...og..
  .ooo...
  orrr#o.
  orrr#o.
  orrrr#o
  .orrro.
  ..ooo..
BITTEN
  ..og...
  ...og..
  ..oo...
  ..o#o..
  ..o#o..
  .orro..
  ..oo...
  .......
CORE
HEART = art(<<~ART)
  .oo.oo.
  ohhohho
  ohhhhho
  .ohhho.
  ..oho..
  ...o...
ART
NOTE = art(<<~ART)
  ..oo
  ..oo
  ..o.
  ..o.
  ooo.
  ooo.
ART
ZED = art(<<~ART)
  yyyy
  ..y.
  .y..
  yyyy
ART
BOLT = art(<<~ART)
  ..yyy
  .yyy.
  yyyy.
  ..yy.
  .yy..
  .y...
  y....
ART

# The pet's voice: a handful of chirps, each written once as a WAV file and
# played in the background with afplay.
class Chirps
  RATE = 22_050

  attr_reader :last_file, :player

  def initialize
    @dir = Dir.mktmpdir("pixel-pet")
    @files = {}
  end

  def play(name)
    @last_file = @files[name] ||= write(name, samples(name))
    @player = Process.detach(spawn("afplay", @last_file, out: File::NULL, err: File::NULL))
  rescue SystemCallError
    # no afplay here (not a Mac): the pet chirps in silence
  end

  # Each chirp is a few notes, [start pitch, end pitch, seconds], sung in order;
  # a pitch of 0 is a little rest.
  def samples(name)
    notes = {
      hello: [[520, 780, 0.09], [780, 1040, 0.12]],
      nom: [[700, 520, 0.07], [0, 0, 0.03], [620, 440, 0.08]],
      boing: [[260, 900, 0.22]],
      giggle: [[1100, 1300, 0.05], [0, 0, 0.02], [1250, 1450, 0.05], [0, 0, 0.02], [1150, 1500, 0.07]],
      yawn: [[640, 300, 0.5]],
      wake: [[300, 700, 0.25]],
      no: [[330, 300, 0.1], [0, 0, 0.04], [262, 240, 0.16]],
      crack: [[1800, 1600, 0.03]],
      hatch: [[523, 523, 0.08], [659, 659, 0.08], [784, 784, 0.08], [1047, 1047, 0.2]],
    }.fetch(name)
    notes.flat_map { |from, to, seconds| tone(from, to, seconds) }
  end

  private

  # A soft square wave gliding from one pitch to another, with a quick fade in and out.
  def tone(from, to, seconds)
    count = (RATE * seconds).round
    phase = soft = 0.0
    Array.new(count) do |i|
      t = i.fdiv(count)
      phase += (from + (to - from) * t) / RATE
      soft += ((phase % 1 < 0.5 ? 1 : -1) - soft) * 0.25
      from.zero? ? 0.0 : 0.3 * soft * [i / 60.0, 1, (count - i) / 200.0].min
    end
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

# The same chirps on _why's bloopsaphone, when the gem is here.
class BloopsChirps
  TUNES = { hello: "8c5 8g5", nom: "16e5 16 16c5", boing: "4c4", giggle: "32c6 32e6 32g6 32e6", yawn: "4g4",
            wake: "8c4 8g4", no: "8e4 8c4", crack: "32c7", hatch: "16c5 16e5 16g5 8c6" }

  def initialize
    @song = Bloops.new
    @song.tempo = 280
    @voice = @song.sound(Bloops::SQUARE)
    { volume: 0.4, sustain: 0.1, decay: 0.2, square: 0.4 }.each { |name, value| @voice.send("#{name}=", value) }
  end

  def play(name)
    @song.clear
    @song.tune(@voice, TUNES.fetch(name))
    @song.play
  end
end

Shoes.app(title: "Pixel Pet", width: 520, height: 680, resizable: false) do
  # ---- the little screen ----

  # A grid of dots to paint pictures on, in a slot of its own so it can move.
  def dots(cols, rows, col, row)
    cells = nil
    slot = stack(left: LCD_X + col * DOT, top: LCD_Y + row * DOT, width: cols * DOT, height: rows * DOT) do
      nostroke
      cells = Array.new(rows) { |y| Array.new(cols) { |x| rect(x * DOT, y * DOT, DOT - 1, DOT - 1, hidden: true) } }
    end
    { slot: slot, cells: cells, shown: {} }
  end

  # Paints a picture onto a grid, touching only the dots that change.
  def paint(grid, picture)
    grid[:cells].each_with_index do |cells, y|
      cells.each_with_index do |cell, x|
        letter = picture[y] && picture[y][x] || "."
        look = [letter, @night]
        next if grid[:shown][[x, y]] == look

        grid[:shown][[x, y]] = look
        letter == "." ? cell.hide : cell.style(fill: ink(PAINT[letter]), hidden: false)
      end
    end
  end

  # At night everything on the screen sinks towards the dark blue.
  def ink(color, alpha = 1.0)
    color = color.zip(NIGHT).map { |c, n| (c * 0.55 + n * 0.45).round } if @night
    rgb(*color, alpha)
  end

  # Moves a grid to a dot on the screen, and does nothing if it is already there.
  def place(grid, col, row)
    return if grid[:at] == [col, row]

    grid[:at] = [col, row]
    grid[:slot].move(LCD_X + col * DOT, LCD_Y + row * DOT)
  end

  def light(night)
    return if @night == night

    @night = night
    @screen.fill = rgb(*(night ? NIGHT : DAY))
    @grain.each { |dot| dot.fill = night ? rgb(255, 255, 255, 0.035) : rgb(0, 0, 0, 0.035) }
    [@pet_grid, @apple, *@floaters.map { |floater| floater[:grid] }].each { |grid| grid[:shown].clear }
  end

  # ---- remembering ----

  def load_pet
    saved = JSON.parse(File.read(SAVE_FILE)) if File.exist?(SAVE_FILE)
    new_pet(saved["name"]).merge(saved) if saved.is_a?(Hash) && saved["name"]
  rescue JSON::ParserError, SystemCallError
    nil
  end

  def new_pet(name)
    now = Time.now.to_i
    { "name" => name, "born" => now, "seen" => now, "food" => 70.0, "joy" => 80.0, "energy" => 90.0, "asleep" => false }
  end

  def save_pet
    @pet["seen"] = Time.now.to_i
    FileUtils.mkdir_p(File.dirname(SAVE_FILE))
    File.write(SAVE_FILE, JSON.pretty_generate(@pet))
  rescue SystemCallError
    # somewhere read-only: the pet lives on, it just won't remember this visit
  end

  # Time passed while the app was closed: gently, and never all the way down.
  def catch_up
    hours = [(Time.now.to_i - @pet["seen"].to_i) / 3600.0, 0].max
    if @pet["asleep"]
      change("energy", hours * 30)
    else
      change("energy", -hours * 6)
    end
    change("food", -hours * 8, floor: 12)
    change("joy", -hours * 6, floor: 12)
    hours
  end

  def change(stat, amount, floor: 0)
    @pet[stat] = (@pet[stat] + amount).clamp([floor, @pet[stat]].min, 100).round(2)
    show_meters
  end

  def days_old
    (Time.now.to_i - @pet["born"].to_i) / 86_400 + 1
  end

  def away(hours)
    return "a moment" if hours < 1.0 / 60
    return "#{(hours * 60).round} minutes" if hours < 1
    return "#{hours.round} #{hours.round == 1 ? "hour" : "hours"}" if hours < 36

    "#{(hours / 24).round} days"
  end

  # ---- how it feels ----

  def mood
    return :asleep if @pet["asleep"]
    return :sad if @pet["food"] < 25 || @pet["joy"] < 20
    return :sleepy if @pet["energy"] < 20
    return :happy if @pet["joy"] > 70 && @pet["food"] > 50

    :content
  end

  def feeling
    name = @pet["name"]
    case mood
    when :asleep then "#{name} is fast asleep."
    when :sad then @pet["food"] < 25 ? "#{name} is hungry." : "#{name} is bored. Play?"
    when :sleepy then "#{name} can hardly keep its eyes open."
    when :happy then "#{name} is having a lovely day."
    else "#{name} is doing fine."
    end
  end

  def say(words)
    show_status words
    @said_at = @frame
  end

  def show_status(words)
    @status.replace(words) unless @status.text == words
  end

  def show_meters
    return unless @meters

    @meters.each do |stat, bar|
      width = [58 * @pet[stat] / 100, 6].max.round
      bar.width = @bar_widths[stat] = width unless @bar_widths[stat] == width
    end
  end

  # ---- things to do ----

  def feed
    return refuse("#{@pet["name"]} is asleep. Shh.") if @pet["asleep"]
    return refuse("#{@pet["name"]} is full.") if @pet["food"] > 92

    act(:feed, 24)
    say "Nom nom nom."
  end

  def play_with
    return refuse("#{@pet["name"]} is asleep. Shh.") if @pet["asleep"]
    return refuse("Too sleepy to play.") if @pet["energy"] < 12

    act(:play, 24)
    say "Wheee!"
  end

  def bedtime
    if @pet["asleep"]
      @pet["asleep"] = false
      light(false)
      chirp :wake
      say "Good morning, #{@pet["name"]}."
    else
      @pet["asleep"] = true
      light(true)
      chirp :yawn
      say "Night night, #{@pet["name"]}."
    end
    @sleep_label.replace(@pet["asleep"] ? "Wake" : "Sleep")
    save_pet
  end

  def pat
    return hatch_tap unless @pet
    return say("Zzz...") if @pet["asleep"]

    act(:pat, 12)
    change("joy", 4)
    say "#{@pet["name"]} loves that."
    save_pet
  end

  def refuse(words)
    act(:no, 10)
    say words
  end

  def act(name, frames)
    @action = { name: name, frame: 0, frames: frames }
    chirp(name == :pat ? :giggle : name == :play ? :boing : name == :no ? :no : :nom)
  end

  def chirp(name)
    @voice.play(name)
  end

  # Sends a heart, a note or a Z floating up from the pet.
  def float(picture, col)
    floater = @floaters.find { |f| f[:age] < 0 } || @floaters.max_by { |f| f[:age] }
    paint(floater[:grid], picture)
    floater.merge!(age: 0, col: col, row: PET_ROW + 2)
    place(floater[:grid], col, floater[:row])
    floater[:grid][:slot].show
  end

  # ---- the egg ----

  def hatch_tap
    return if @cracks >= 3

    @cracks += 1
    if @cracks < 3
      paint(@pet_grid, CRACKS[@cracks])
      chirp :crack
      say(@cracks == 1 ? "It moved!" : "Almost...")
    else
      chirp :hatch
      paint(@pet_grid, FACES[:joy])
      say "Hello! What will you call me?"
      @naming.show
      @name_box.focus
    end
  end

  def name_it
    name = @name_box.text.strip
    name = "Mochi" if name.empty?
    @pet = new_pet(name[0, 16])
    save_pet
    @naming.hide
    @panel.show
    show_meters
    @title.replace name.upcase
    @age.replace "day 1"
    act(:pat, 12)
    say "#{name} is so happy to meet you."
  end

  # ---- twelve frames a second ----

  def tick
    @frame += 1
    return wobble_egg unless @pet

    action_frame
    @floaters.each { |floater| drift(floater) }
    show_status(feeling) if @said_at && @frame - @said_at > 48
  end

  def wobble_egg
    place(@pet_grid, PET_COL + [0, 0, 0, 0, 0, 0, 1, 0, -1, 0][@frame / 2 % 10], PET_ROW)
  end

  # What the pet is doing this frame: an action if it has one, else just being.
  def action_frame
    face = mood
    col, row = PET_COL, PET_ROW
    if @action
      face, col, row = doing(@action)
      @action[:frame] += 1
      @action = nil if @action[:frame] >= @action[:frames]
    else
      row += 1 if @frame / 6 % 2 == 1 && face != :asleep # breathing
      face = :blink if face != :asleep && (@frame % 50 < 2 || @frame % 50 == 5)
      float(ZED, PET_COL + 13) if face == :asleep && @frame % 18 == 0
    end
    paint(@pet_grid, glance(FACES[face], face == :asleep ? 0 : @look))
    place(@pet_grid, col, row)
    paint(@apple, APPLES[[@action && @action[:name] == :feed ? @action[:frame] / 8 : 3, 3].min] || [])
  end

  # The same face with its eyes moved a dot towards your pointer.
  def glance(picture, dx)
    return picture if dx.zero?

    picture.each_with_index.map do |line, y|
      next line unless (6..8).cover?(y)

      dots = line.chars
      moved = dots.map { |letter| "ew".include?(letter) ? "#" : letter }
      dots.each_with_index { |letter, x| moved[x + dx] = letter if "ew".include?(letter) }
      moved.join
    end
  end

  def doing(action)
    frame = action[:frame]
    case action[:name]
    when :feed
      finish(frame, "food" => 30, "joy" => 4) if frame == action[:frames] - 1
      [frame % 8 < 4 ? :eat : :chew, PET_COL - 3, PET_ROW]
    when :play
      finish(frame, "joy" => 22, "energy" => -12, "food" => -6) if frame == action[:frames] - 1
      float(NOTE, PET_COL + 15) if frame % 8 == 0
      hop = [0, 2, 3, 2, 0, 0, 0, 0][frame % 8]
      [:joy, PET_COL, PET_ROW - hop]
    when :pat
      float(HEART, PET_COL + 12) if frame == 0
      [:joy, PET_COL, PET_ROW + (frame < 4 ? 1 : 0)]
    else # no
      [:sad, PET_COL + [0, -1, 0, 1][frame % 4], PET_ROW]
    end
  end

  def finish(_frame, changes)
    changes.each { |stat, amount| change(stat, amount) }
    save_pet
  end

  def drift(floater)
    return if floater[:age] < 0

    floater[:age] += 1
    floater[:row] -= 1 if floater[:age].even?
    place(floater[:grid], floater[:col], floater[:row])
    return unless floater[:age] > 14 || floater[:row] < 0

    floater[:age] = -1
    floater[:grid][:slot].hide
  end

  # ---- the egg-shaped case ----

  def shell(cx, top, width, height)
    w, h = width / 2.0, height
    shape do
      move_to cx, top
      curve_to cx + w * 0.6, top, cx + w, top + h * 0.3, cx + w, top + h * 0.58
      curve_to cx + w, top + h * 0.84, cx + w * 0.56, top + h, cx, top + h
      curve_to cx - w * 0.56, top + h, cx - w, top + h * 0.84, cx - w, top + h * 0.58
      curve_to cx - w, top + h * 0.3, cx - w * 0.6, top, cx, top
    end
  end

  # A round button on the case, with its label underneath. The panel it sits
  # in starts at y = 360, so these numbers count from there.
  def case_button(x, label, &on_click)
    words = nil
    nostroke
    fill rgb(120, 60, 90, 0.16)
    oval x, 97, 56, center: true
    fill "#fff6ee".."#ffe3ec"
    stroke rgb(120, 60, 90, 0.35)
    strokewidth 2
    knob = oval x, 92, 56, center: true, cursor: :hand_cursor
    knob.click do
      knob.top = 95
      timer(0.12) { knob.top = 92 }
      on_click.call
    end
    stack left: x - 50, top: 126, width: 100 do
      words = para label, align: "center", size: 12, weight: "semibold", stroke: "#8a4f6d", margin: 0
    end
    words
  end

  # A small pixel icon and a bar that shows how full one of the pet's needs is.
  def meter(x, stat, picture, color)
    nostroke
    picture.each_with_index do |line, y|
      line.each_char.with_index do |letter, dx|
        rect x + dx * 2, 12 + y * 2 - picture.size + 7, 2, 2, fill: rgb(*PAINT[letter]) unless letter == "."
      end
    end
    fill rgb(255, 255, 255, 0.65)
    rect x + 20, 16, 58, 8, curve: 4
    fill color
    @meters[stat] = rect x + 20, 16, 58, 8, curve: 4
  end

  # ---- building it ----

  @frame = 0
  @look = 0
  @seconds = 0
  @cracks = 0
  @night = false
  @voice = defined?(Bloops) ? BloopsChirps.new : Chirps.new
  @pet = load_pet
  @meters = {}
  @bar_widths = {}

  background "#fde7ef".."#e8e2ff"
  nostroke
  fill rgb(255, 255, 255, 0.35)
  [[60, 90, 90], [470, 150, 60], [440, 610, 110], [40, 560, 70]].each { |x, y, d| oval x, y, d, center: true }

  # the case, its key ring, and a shine on the shell
  nofill
  stroke "#e29db8"
  strokewidth 6
  oval 260, 30, 34, center: true
  nostroke
  fill rgb(150, 70, 110, 0.12)
  shell 264, 42, 440, 556
  fill "#ffd6e5".."#ffb4cf"
  stroke "#e58fb1"
  strokewidth 3
  shell 260, 36, 440, 556
  nostroke
  fill rgb(255, 255, 255, 0.4)
  oval 92, 400, 22, 150, center: true
  fill rgb(255, 255, 255, 0.35)
  oval 104, 300, 12, center: true

  # the name plate
  stack left: 110, top: 96, width: 300 do
    @title = para "", align: "center", size: 13, weight: "bold", kerning: 3, stroke: "#8a4f6d", margin: 0
    @age = para "", align: "center", size: 10, stroke: "#b07896", margin: [0, 2, 0, 0]
  end

  # the screen: a bezel, the glass, and a faint grain of dots like a real LCD
  fill "#fff0f5"
  stroke "#e8a6c0"
  strokewidth 2
  rect LCD_X - 12, LCD_Y - 12, LCD_COLS * DOT + 24, LCD_ROWS * DOT + 24, curve: 22
  nostroke
  @screen = rect LCD_X - 2, LCD_Y - 2, LCD_COLS * DOT + 4, LCD_ROWS * DOT + 4, curve: 12, fill: rgb(*DAY)
  @grain = (0...LCD_COLS).flat_map do |x|
    (0...LCD_ROWS).map { |y| rect LCD_X + x * DOT, LCD_Y + y * DOT, DOT - 1, DOT - 1, fill: rgb(0, 0, 0, 0.035) }
  end

  # a gleam across the glass, under the pet so a pat can land anywhere on it
  fill rgb(255, 255, 255, 0.12)
  shape do
    move_to LCD_X - 2, LCD_Y + 10
    curve_to LCD_X - 2, LCD_Y + 2, LCD_X + 2, LCD_Y - 2, LCD_X + 12, LCD_Y - 2
    line_to LCD_X + 110, LCD_Y - 2
    line_to LCD_X - 2, LCD_Y + 96
    line_to LCD_X - 2, LCD_Y + 10
  end

  @floaters = Array.new(4) { { grid: dots(7, 6, 0, 0), age: -1 } }
  @floaters.each { |floater| floater[:grid][:slot].hide }
  @apple = dots(7, 8, 18, 10)
  @pet_grid = dots(16, 16, PET_COL, PET_ROW)
  @pet_grid[:slot].click { pat }
  @pet_grid[:slot].style(cursor: :hand_cursor)

  # meters, and the three buttons
  @panel = stack(left: 0, top: 360, width: 520, height: 150, hidden: @pet.nil?) do
    meter 124, "food", APPLES[0].first(7), "#ef476f"
    meter 218, "joy", HEART, "#ff5d8f"
    meter 312, "energy", BOLT, "#f4a93b"
    case_button(166, "Feed") { feed }
    case_button(260, "Play") { play_with }
    @sleep_label = case_button(354, "Sleep") { bedtime }
  end

  # naming, the first time only
  @naming = stack(left: 110, top: 380, width: 300, height: 130, hidden: true) do
    para "Name your pet", align: "center", size: 13, weight: "semibold", stroke: "#8a4f6d", margin: [0, 0, 0, 8]
    flow margin_left: 22 do
      @name_box = edit_line width: 170, margin_right: 8
      button("Hello!") { name_it }
    end
  end

  stack left: 20, top: 618, width: 480 do
    @status = para "", align: "center", size: 15, weight: "medium", stroke: "#6b3d58", margin: 0
  end

  # its eyes follow the pointer across the window
  motion do |x, _y|
    @look = x < 200 ? -1 : x > 320 ? 1 : 0
  end

  keypress do |key|
    next unless @pet

    case key
    when "f" then feed
    when "p" then play_with
    when "s" then bedtime
    end
  end

  if @pet
    hours = catch_up
    @title.replace @pet["name"].upcase
    @age.replace "day #{days_old}"
    @sleep_label.replace(@pet["asleep"] ? "Wake" : "Sleep")
    light(@pet["asleep"])
    paint(@pet_grid, FACES[mood])
    show_meters
    chirp :hello unless @pet["asleep"]
    say "#{@pet["name"]} missed you. You were away #{away(hours)}."
    save_pet
  else
    paint(@pet_grid, EGG)
    @title.replace "PIXEL PET"
    @age.replace "not hatched yet"
    say "Something is about to hatch. Tap the egg."
  end

  every(1) do
    next unless @pet

    if @pet["asleep"]
      change("energy", 0.5)
      change("food", -0.03, floor: 10)
    else
      change("energy", -0.04)
      change("food", -0.06, floor: 10)
      change("joy", -0.05, floor: 10)
    end
    @seconds += 1
    save_pet if @seconds % 10 == 0
  end

  animate(12) { tick }
end
