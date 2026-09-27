# Pomodoro: twenty-five minutes on one thing, then a break.
#
# Space starts and pauses, R resets. Four focus sessions earn a long break.

MODES = {
  "Focus" => { minutes: 25, color: [224, 103, 79] },
  "Short break" => { minutes: 5, color: [79, 157, 126] },
  "Long break" => { minutes: 15, color: [74, 134, 184] },
}
INK = "#26343d"
MUTED = "#8b8f93"
TRACK = "#e4ddd3"
DIGITS = "Helvetica Neue, sans-serif" # its figures are all one width, so the time never wobbles

CX, CY, RADIUS = 220, 262, 124 # the ring

Shoes.app(title: "Pomodoro", width: 440, height: 580, resizable: false) do
  def clock_text(seconds)
    format("%02d:%02d", seconds / 60, seconds % 60)
  end

  def color(alpha = 1.0)
    rgb(*MODES[@mode][:color], alpha)
  end

  def fraction_left
    @left.to_f / @total
  end

  # A point on the ring, `angle` radians clockwise from three o'clock.
  def on_ring(angle, radius = RADIUS)
    [CX + radius * Math.cos(angle), CY + radius * Math.sin(angle)]
  end

  # A pill-shaped button: a rounded background with a label on it.
  # Returns both, so the caller can recolour and relabel it later.
  def pill(label, width:, fill:, text:, &on_click)
    look = words = nil
    button = stack(width: width + 12, height: 46, margin_left: 6, margin_right: 6) do
      look = background fill, curve: 23
      border rgb(0, 0, 0, 0.07), strokewidth: 1, curve: 23
      words = para label, align: "center", stroke: text, size: 14, weight: "semibold", margin_top: 14
    end
    button.click(&on_click)
    [look, words]
  end

  # The coloured arc is the time left. It empties clockwise from twelve o'clock,
  # and the white dot rides its leading end.
  def draw_ring
    start = -Math::PI / 2 + 2 * Math::PI * (1 - @shown)
    @arc.style(stroke: color, angle1: start)
    @arc.hidden = @shown < 0.002
    @dot.stroke = color
    @dot.move(*on_ring(start))
  end

  # In and out every five seconds (a hundred frames), like slow breathing.
  def breathe(frame)
    depth = (1 - Math.cos(frame * Math::PI / 50)) / 2
    @halo.each { |ring| ring.stroke = color(0.02 + 0.04 * depth) }
  end

  def show_mode
    @segments.each do |name, (chip, label)|
      chip.hidden = name != @mode
      label.stroke = name == @mode ? INK : MUTED
    end
    @caption.replace @mode.upcase
    @start_look.fill = color
    @dots.each_with_index { |dot, i| dot.fill = i < @sessions % 4 ? color : TRACK }
    draw_ring
  end

  def choose(mode)
    @mode = mode
    @total = @left = MODES[mode][:minutes] * 60
    pause
    @digits.replace clock_text(@left)
    show_mode
    @glide.start
  end

  def start
    @running = true
    @ticker.start
    @start_label.replace "Pause"
    @glide.start
  end

  def pause
    @running = false
    @ticker.stop
    @halo.each { |ring| ring.stroke = color(0) }
    @start_label.replace(@left < @total ? "Resume" : "Start")
  end

  def toggle
    @running ? pause : start
  end

  # A finished focus session earns a break: every fourth one, a long one.
  def finish
    if @mode == "Focus"
      @sessions += 1
      choose(@sessions % 4 == 0 ? "Long break" : "Short break")
    else
      choose("Focus")
    end
  end

  def tick
    @left -= 1
    @digits.replace clock_text(@left)
    @glide.start
    finish if @left <= 0
  end

  @mode = "Focus"
  @sessions = 0
  @running = false
  @shown = 1.0

  background "#f7f4ef".."#ebe4da"

  # the mode switch: three segments, the chosen one on a white chip
  @segments = {}
  flow left: 34, top: 28, width: 372, height: 40 do
    background rgb(38, 52, 61, 0.06), curve: 20
    MODES.each_key do |name|
      segment = stack(width: 124, height: 40) do
        chip = background white, curve: 16, margin: 4
        label = para name, align: "center", size: 13, weight: "medium", margin_top: 12
        @segments[name] = [chip, label]
      end
      segment.click { choose(name) }
    end
  end

  # sixty ticks round the ring, every fifth one longer
  cap :curve
  60.times do |i|
    angle = i * Math::PI / 30
    long = i % 5 == 0
    stroke rgb(38, 52, 61, long ? 0.28 : 0.14)
    strokewidth long ? 2 : 1
    line(*on_ring(angle, long ? RADIUS + 16 : RADIUS + 19), *on_ring(angle, RADIUS + 24))
  end

  # the halo: three soft rings behind the ring, dark until the clock runs
  nofill
  @halo = [36, 26, 16].map do |width|
    strokewidth width
    oval CX, CY, RADIUS * 2, center: true, stroke: rgb(0, 0, 0, 0)
  end
  strokewidth 12
  oval CX, CY, RADIUS * 2, center: true, stroke: TRACK
  @arc = arc CX - RADIUS, CY - RADIUS, RADIUS * 2, RADIUS * 2, -Math::PI / 2, 3 * Math::PI / 2
  strokewidth 4
  fill white
  @dot = oval CX, CY - RADIUS, 20, center: true

  stack left: CX - 120, top: CY - 58, width: 240 do
    @digits = para "25:00", align: "center", size: 64, weight: "light", family: DIGITS, stroke: INK, margin: 0
    @caption = para "FOCUS", align: "center", size: 11, weight: "semibold", kerning: 3, stroke: MUTED, margin: [0, 6, 0, 0]
  end

  # one dot for each focus session in this round of four
  nostroke
  @dots = (0..3).map { |i| oval CX - 21 + i * 14, CY + 50, 7, center: true, fill: TRACK }

  flow left: 76, top: 480, width: 300 do
    @start_look, @start_label = pill("Start", width: 150, fill: white, text: white) { toggle }
    pill("Reset", width: 110, fill: white, text: INK) { choose(@mode) }
  end

  stack left: 0, top: 540, width: 440 do
    inscription "Space starts and pauses. R resets.", align: "center", stroke: MUTED
  end

  keypress do |key|
    toggle if key == " "
    choose(@mode) if key == "r"
  end

  @ticker = every(1) { tick if @running }

  # Glides the ring towards the time left and breathes the halo while the clock runs.
  # It stops itself once nothing moves, so a paused timer costs nothing.
  @glide = animate(20) do |frame|
    unless @shown == fraction_left
      @shown += (fraction_left - @shown) * 0.3
      @shown = fraction_left if (fraction_left - @shown).abs < 0.0005
      draw_ring
    end
    breathe(frame) if @running
    @glide.stop if !@running && @shown == fraction_left
  end

  choose "Focus"
end
