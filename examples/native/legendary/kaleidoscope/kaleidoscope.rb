# Kaleidoscope: draw in one slice and watch it bloom in all the others.
#
# Press and drag inside the circle. Each stroke is copied round the centre and
# mirrored, the way two mirrors in a tube copy the beads between them. Pick a
# palette, a brush and how many mirrors; turn on Spin and draw on a turning plate.

W, H = 940, 660
CX, CY, RADIUS = 606, 330, 300 # the lens
SIDEBAR = 262

PALETTES = {
  "Aurora" => ["#3ee6c1", "#58b4ff", "#b48cff", "#7cf29a", "#f5f7ff"],
  "Ember" => ["#ff5e57", "#ffb347", "#ff6fae", "#ffd166", "#fff1e6"],
  "Lagoon" => ["#00c2d1", "#c3f73a", "#1f8fff", "#7af0e0", "#ffffff"],
  "Candy" => ["#ff8fcf", "#9ad8ff", "#fff08a", "#b7f5c8", "#d9b8ff"],
}
BRUSHES = [2, 5, 10]
MIRRORS = [8, 12, 16]
INK = "#f3eefe"
MUTED = "#8f86a8"

# One line drawn by hand: its points (relative to the centre, before any spin),
# its two colours and brush, and the shapes that show it.
Stroke = Struct.new(:points, :color, :partner, :size, :shapes)

Shoes.app(title: "Kaleidoscope", width: W, height: H, resizable: false) do
  # ---------------------------------------------------------------- the mirrors

  # Every copy of a point: turned round the centre `turns` times, then the same
  # again reflected. Plain copies go in the first list, reflections in the second.
  def copies(dx, dy)
    turns = @mirrors / 2
    plain = []
    mirrored = []
    turns.times do |k|
      a = 2 * Math::PI * k / turns
      cos, sin = Math.cos(a), Math.sin(a)
      plain << [CX + dx * cos - dy * sin, CY + dx * sin + dy * cos]
      mirrored << [CX + dx * cos + dy * sin, CY + dx * sin - dy * cos]
    end
    [plain, mirrored]
  end

  # A smooth path through the points: each piece bends towards a point and
  # ends halfway to the next one. Returned as [command, *coordinates] steps.
  def smooth(points)
    first = points.first
    return [[:move_to, *first], [:line_to, first[0] + 0.1, first[1]]] if points.size == 1

    mid = ->(p, q) { [(p[0] + q[0]) / 2.0, (p[1] + q[1]) / 2.0] }
    steps = [[:move_to, *first], [:line_to, *mid.(points[0], points[1])]]
    points.each_cons(3) do |a, b, c|
      from, to = mid.(a, b), mid.(b, c)
      pull = ->(p) { [p[0] + (b[0] - p[0]) * 2 / 3.0, p[1] + (b[1] - p[1]) * 2 / 3.0] }
      steps << [:curve_to, *pull.(from), *pull.(to), *to]
    end
    steps << [:line_to, *points.last]
  end

  # One shape holding every plain copy (or every reflection) of a path, so a
  # stroke is six shapes however many mirrors there are. The copies are
  # symmetric about the centre, so the shape's middle is the lens's middle and
  # `transform :center` spins it about the right point.
  def kaleido_shape(steps, reflected)
    side = reflected ? 1 : 0
    moved = steps.map { |command, *xy| [command, xy.each_slice(2).map { |x, y| copies(x, y)[side] }] }
    shape do
      (@mirrors / 2).times do |k|
        moved.each { |command, points| send(command, *points.flat_map { |copy| copy[k] }) }
      end
    end
  end

  # A soft glow under a crisp line, each in its two colours.
  def paint_stroke(trail, steps)
    shapes = []
    @canvas.append do
      transform :center
      cap :curve
      nofill
      [[trail.size * 2 + 7, 0.2], [trail.size, 1.0]].each do |width, alpha|
        strokewidth width
        stroke rgb(*hex(trail.color), alpha)
        shapes << kaleido_shape(steps, false)
        stroke rgb(*hex(trail.partner), alpha)
        shapes << kaleido_shape(steps, true)
      end
    end
    on_the_plate(shapes)
  end

  # New shapes start at the plate's current turn, so they land where they were drawn.
  def on_the_plate(shapes)
    shapes.each { |shape| shape.style(rotate: @angle.round(2)) } if @angle != 0
    shapes
  end

  def hex(color)
    color.delete("#").scan(/../).map { |pair| pair.to_i(16) }
  end

  # ---------------------------------------------------------------- drawing

  # Where a point on the screen sits in the drawing, allowing for the spin,
  # kept inside the lens.
  def in_lens(x, y)
    a = @angle * Math::PI / 180
    sx, sy = x - CX, y - CY
    dx = sx * Math.cos(a) - sy * Math.sin(a)
    dy = sx * Math.sin(a) + sy * Math.cos(a)
    reach = Math.hypot(dx, dy)
    limit = RADIUS - 10
    reach > limit ? [dx * limit / reach, dy * limit / reach] : [dx, dy]
  end

  def next_colors
    colors = PALETTES[@palette]
    @turn = (@turn + 1) % colors.size
    [colors[@turn], colors[(@turn + 1) % colors.size]]
  end

  def begin_stroke(x, y)
    end_stroke # in case the last one was let go outside the window
    color, partner = @upcoming
    @live = Stroke.new([in_lens(x, y)], color, partner, @brush, [])
    @live.shapes = paint_stroke(@live, smooth(@live.points))
  end

  # While the mouse moves, only the newest piece is drawn, in the brush's own
  # colour; letting go swaps the pieces for one smooth stroke with its glow.
  def extend_stroke(x, y)
    point = in_lens(x, y)
    last = @live.points.last
    return if Math.hypot(point[0] - last[0], point[1] - last[1]) < 3

    @live.points << point
    trail = @live
    segment = [[:move_to, *last], [:line_to, *point]]
    shapes = []
    @canvas.append do
      transform :center
      cap :curve
      strokewidth trail.size
      stroke trail.color
      shapes << kaleido_shape(segment, false)
      stroke trail.partner
      shapes << kaleido_shape(segment, true)
    end
    @live.shapes.concat(on_the_plate(shapes))
  end

  def end_stroke
    return unless @live

    @live.shapes.each(&:remove)
    @live.shapes = paint_stroke(@live, smooth(@live.points))
    @strokes << @live
    @live = nil
    @upcoming = next_colors
    show_brushes
  end

  def undo
    @strokes.pop&.shapes&.each(&:remove)
  end

  def clear_all
    @canvas.clear
    @strokes = []
  end

  # Redraws every stroke, for when the number of mirrors changes.
  def redraw
    @canvas.clear
    @strokes.each { |trail| trail.shapes = paint_stroke(trail, smooth(trail.points)) }
  end

  # ---------------------------------------------------------------- surprise me

  # A handful of strokes made from curves: petals, rings, waves, loops and spirals.
  def surprise
    end_stroke
    clear_all
    colors = PALETTES[@palette]
    rng = Random.new
    rng.rand(6..8).times do |i|
      points = case i % 5
               when 0 then petal(rng)
               when 1 then ring(rng)
               when 2 then wave(rng)
               when 3 then loop_at(rng)
               else spiral(rng)
               end
      color = colors[(i + @turn) % colors.size]
      partner = colors[(i + @turn + 1) % colors.size]
      trail = Stroke.new(points, color, partner, BRUSHES.sample(random: rng), [])
      trail.shapes = paint_stroke(trail, smooth(trail.points))
      @strokes << trail
    end
  end

  def polar(r, a)
    [r * Math.cos(a), r * Math.sin(a)]
  end

  def petal(rng)
    r1, r2 = rng.rand(10..80), rng.rand(150..280)
    a, bulge = rng.rand(0.0..0.8), rng.rand(0.2..0.5)
    (0..30).map { |i| t = i / 30.0; polar(r1 + (r2 - r1) * t, a + bulge * Math.sin(Math::PI * t)) }
  end

  def ring(rng)
    r = rng.rand(60..270)
    a = rng.rand(0.0..0.3)
    (0..24).map { |i| polar(r, a + 0.75 * i / 24.0) }
  end

  def wave(rng)
    r1, r2 = rng.rand(40..120), rng.rand(180..280)
    a, wiggle = rng.rand(0.1..0.7), rng.rand(0.08..0.2)
    (0..40).map { |i| t = i / 40.0; polar(r1 + (r2 - r1) * t, a + wiggle * Math.sin(6 * Math::PI * t)) }
  end

  def loop_at(rng)
    cx, cy = polar(rng.rand(90..230), rng.rand(0.1..0.7))
    r = rng.rand(12..34)
    (0..28).map { |i| a = 2 * Math::PI * i / 28.0; [cx + r * Math.cos(a), cy + r * Math.sin(a)] }
  end

  def spiral(rng)
    start = rng.rand(0.0..1.0)
    (0..40).map { |i| t = i / 40.0; polar(20 + 240 * t, start + 2.4 * t) }
  end

  # ---------------------------------------------------------------- the sidebar

  def label(text, top)
    para text, size: 10, weight: "semibold", kerning: 2, stroke: MUTED, left: 28, top: top
  end

  # A rounded button. `look` is its background, kept so it can be highlighted.
  def pill(text, left, top, width, &on_click)
    look = nil
    button = stack(left: left, top: top, width: width, height: 36) do
      look = background rgb(255, 255, 255, 0.06), curve: 12
      border rgb(255, 255, 255, 0.1), curve: 12
      para text, align: "center", size: 13, weight: "medium", stroke: INK, margin: [0, 10, 0, 0]
    end
    button.click(&on_click)
    look
  end

  def palette_row(name, top)
    row = stack(left: 24, top: top, width: 214, height: 38) do
      @palette_looks[name] = background(rgb(255, 255, 255, 0.04), curve: 12)
      para name, size: 13, stroke: INK, margin: [14, 11, 0, 0], width: 100
      nostroke
      PALETTES[name].each_with_index { |color, i| oval 118 + i * 20, 19, 13, center: true, fill: color }
    end
    row.click { choose_palette(name) }
  end

  def choose_palette(name)
    @palette = name
    @palette_looks.each { |key, look| look.fill = key == name ? rgb(255, 255, 255, 0.16) : rgb(255, 255, 255, 0.04) }
    @surprise_look&.fill = rgb(*hex(PALETTES[name][0]), 0.28)..rgb(*hex(PALETTES[name][2]), 0.28)
    @turn = -1
    @upcoming = next_colors
    show_brushes
  end

  def choose_brush(size)
    @brush = size
    show_brushes
  end

  # The brush dots wear the colour the next stroke will take.
  def show_brushes
    @brush_dots.each_with_index do |dot, i|
      dot.fill = @upcoming[0]
      @brush_rings[i].stroke = BRUSHES[i] == @brush ? rgb(255, 255, 255, 0.7) : rgb(255, 255, 255, 0)
    end
  end

  def choose_mirrors(count)
    @mirrors = count
    @mirror_looks.each { |n, look| look.fill = n == count ? rgb(255, 255, 255, 0.18) : rgb(255, 255, 255, 0.06) }
    draw_guides
    redraw
  end

  def toggle_spin
    @spinning = !@spinning
    @track.fill = @spinning ? PALETTES[@palette][0] : rgb(255, 255, 255, 0.14)
    @knob.left = @spinning ? 222 : 202
  end

  # Faint lines where the mirrors meet.
  def draw_guides
    @guides.clear do
      transform :center
      stroke rgb(255, 255, 255, 0.05)
      strokewidth 1
      @guide_lines = Array.new(@mirrors / 2) do |k|
        a = Math::PI * k / (@mirrors / 2)
        line CX - RADIUS * Math.cos(a), CY - RADIUS * Math.sin(a), CX + RADIUS * Math.cos(a), CY + RADIUS * Math.sin(a)
      end
    end
  end

  # ---------------------------------------------------------------- the window

  @palette = "Aurora"
  @brush = 5
  @mirrors = 8
  @angle = 0.0
  @spinning = false
  @strokes = []
  @turn = -1
  @upcoming = next_colors
  @palette_looks = {}

  background "#171230".."#08060f", angle: 30
  nostroke
  stars = Random.new(4)
  90.times do
    x = stars.rand(SIDEBAR..W)
    y = stars.rand(0..H)
    next if Math.hypot(x - CX, y - CY) < RADIUS + 20

    oval x, y, stars.rand(1.2..2.4), center: true, fill: rgb(255, 255, 255, stars.rand(0.15..0.5))
  end

  # the lens: a dark glass disc in a soft rim
  fill rgb(120, 90, 200, 0.05)
  oval CX, CY, RADIUS * 2 + 44, center: true
  fill "#07050f"
  oval CX, CY, RADIUS * 2, center: true
  @guides = stack(left: 0, top: 0, width: W, height: H) {}
  @canvas = stack(left: 0, top: 0, width: W, height: H) {}
  nofill
  strokewidth 12
  stroke rgb(255, 255, 255, 0.05)
  oval CX, CY, RADIUS * 2 + 12, center: true
  strokewidth 1.5
  stroke rgb(255, 255, 255, 0.2)
  oval CX, CY, RADIUS * 2, center: true

  # the sidebar
  nostroke
  fill rgb(255, 255, 255, 0.025)
  rect 0, 0, SIDEBAR, H
  fill rgb(255, 255, 255, 0.06)
  rect SIDEBAR - 1, 0, 1, H

  para "Kaleidoscope", size: 26, weight: "light", stroke: INK, left: 26, top: 26
  para "Draw in one slice and watch it bloom in all the others.", size: 12, stroke: MUTED, left: 28, top: 70, width: 210

  label "PALETTE", 124
  PALETTES.keys.each_with_index { |name, i| palette_row(name, 146 + i * 44) }

  label "BRUSH", 334
  @brush_rings = []
  @brush_dots = BRUSHES.each_with_index.map do |size, i|
    x = 46 + i * 44
    nofill
    strokewidth 1.5
    @brush_rings << oval(x, 372, 34, center: true, stroke: rgb(255, 255, 255, 0))
    nostroke
    dot = oval(x, 372, 6 + size * 1.4, center: true)
    ring = oval(x, 372, 34, center: true, fill: rgb(0, 0, 0, 0), cursor: :hand_cursor)
    ring.click { choose_brush(size) }
    dot
  end

  label "MIRRORS", 408
  @mirror_looks = MIRRORS.each_with_index.to_h do |count, i|
    [count, pill("#{count}", 24 + i * 72, 430, 64) { choose_mirrors(count) }]
  end

  label "SPIN", 488
  para "Turn the plate", size: 13, stroke: INK, left: 28, top: 510
  nostroke
  @track = rect(196, 510, 48, 26, curve: 13, fill: rgb(255, 255, 255, 0.14))
  @knob = oval(202, 513, 20, fill: white)
  spin_switch = rect(190, 504, 60, 38, fill: rgb(0, 0, 0, 0), cursor: :hand_cursor)
  spin_switch.click { toggle_spin }

  @surprise_look = pill("Surprise me", 24, 566, 214) { surprise }
  pill("Undo", 24, 610, 103) { undo }
  pill("Clear", 135, 610, 103) { clear_all }

  choose_palette "Aurora"
  choose_mirrors 8

  click do |_button, x, y|
    begin_stroke(x, y) if Math.hypot(x - CX, y - CY) < RADIUS
  end
  motion { |x, y| extend_stroke(x, y) if @live }
  release { end_stroke }

  keypress do |key|
    case key
    when :alt_z, :control_z, "u" then undo
    when "s" then toggle_spin
    when "c" then clear_all
    when "1", "2", "3" then choose_brush(BRUSHES[key.to_i - 1])
    end
  end

  # The plate turns 7.5 degrees a second, taking everything on it along. Every
  # stroke repaints each step, so 24 steps a second keeps a busy plate smooth.
  animate(24) do
    next unless @spinning

    @angle = (@angle + 7.5 / 24) % 360
    turn = @angle.round(2)
    @guide_lines.each { |guide| guide.style(rotate: turn) }
    @strokes.each { |trail| trail.shapes.each { |shape| shape.style(rotate: turn) } }
    @live&.shapes&.each { |shape| shape.style(rotate: turn) }
  end
end
