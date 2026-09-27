# Sketchpad: press, drag and let go to draw.
#
# Pick a colour and a brush from the bar. Undo takes back the last stroke,
# Clear starts a fresh page. The paper-coloured swatch is an eraser.

WIDTH, HEIGHT = 760, 560
BAR = 64 # height of the toolbar
PAPER = "#fbfaf7"
INK = "#2b2d42"
COLORS = [INK, "#ef6f53", "#f4b942", "#58a55c", "#3a86c8", "#8e6bbf", "#e86fa4", PAPER]
BRUSHES = [3, 8, 16]

Shoes.app(title: "Sketchpad", width: WIDTH, height: HEIGHT, resizable: false) do
  # A pill-shaped button with a label.
  def pill(label, left, &on_click)
    button = stack(left: left, top: 15, width: 64, height: 34, cursor: :hand_cursor) do
      background "#f1efea", curve: 17
      para label, align: "center", size: 13, weight: "medium", stroke: INK, margin_top: 9
    end
    button.click(&on_click)
  end

  # The brush previews take the colour too (a pale grey for the eraser).
  def choose_color(color, x)
    @color = color
    @color_ring.move(x, BAR / 2)
    @brush_dots.each { |dot| dot.fill = color == PAPER ? "#d6d1c7" : color }
  end

  def choose_brush(size, x)
    @brush = size
    @brush_ring.move(x, BAR / 2)
  end

  # Mouse positions are window coordinates; the paper starts below the bar.
  def on_paper(x, y)
    [x, y - BAR]
  end

  def start_stroke(x, y)
    @stroke = []
    @pen = @mid = @mouse = on_paper(x, y)
    ink do # a round dab, so a click alone leaves a dot
      nostroke
      oval(*@pen, @brush, center: true, fill: @color)
    end
  end

  # Strokes stay smooth however the mouse moves. The pen trails the mouse by half
  # a step, which irons out pixel-sized stairs, and each piece runs from one
  # halfway point to the next, bending towards the pen in between.
  def extend_stroke(x, y)
    @mouse = on_paper(x, y)
    pen = halfway(@pen, @mouse)
    mid = halfway(@pen, pen)
    from, via = @mid, @pen
    ink { bend(from, via, mid) }
    @pen, @mid = pen, mid
  end

  def end_stroke
    return unless @stroke

    from, to = @mid, @mouse
    ink { line(*from, *to) }
    @strokes << @stroke
    @stroke = nil
  end

  # Draws on the ink layer in the chosen colour and brush, and remembers
  # what it drew as part of this stroke, for undo.
  def ink
    @ink.append do
      stroke @color
      strokewidth @brush
      cap :curve
      nofill
      @stroke << yield
    end
  end

  def halfway(a, b)
    [(a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0]
  end

  # A curve from `from` to `to` that leans towards `via`, the way a pen passes a corner.
  def bend(from, via, to)
    pull = ->(point) { point.zip(via).map { |p, v| p + (v - p) * 2 / 3.0 } }
    shape do
      move_to(*from)
      curve_to(*pull.(from), *pull.(to), *to)
    end
  end

  def undo
    @strokes.pop&.each(&:remove)
  end

  @color = INK
  @brush = 8
  @strokes = []

  # the paper, with a faint grid of dots, and a layer on top for the ink
  stack left: 0, top: BAR, width: WIDTH, height: HEIGHT - BAR do
    background PAPER
    nostroke
    fill "#dcd8cf"
    (12..WIDTH).step(24) do |x|
      (12..HEIGHT - BAR).step(24) { |y| oval x, y, 2, center: true }
    end
    @ink = stack(left: 0, top: 0, width: WIDTH, height: HEIGHT - BAR) {}
  end

  # the toolbar
  stack left: 0, top: 0, width: WIDTH, height: BAR do
    background white
    background "#e7e3dc", top: BAR - 1, height: 1
    para "Sketchpad", size: 15, weight: "semibold", stroke: INK, margin: [22, 21, 0, 0]
  end

  nofill
  strokewidth 2
  stroke INK
  @color_ring = oval 150, BAR / 2, 36, center: true
  COLORS.each_with_index do |color, i|
    x = 150 + i * 40
    stroke color == PAPER ? "#d6d1c7" : color
    strokewidth 1
    fill color
    swatch = oval x, BAR / 2, 26, center: true, cursor: :hand_cursor
    swatch.click { choose_color(color, x) }
  end

  stroke "#e7e3dc"
  line 482, 18, 482, BAR - 18

  nostroke
  fill "#efece6"
  @brush_ring = oval 544, BAR / 2, 32, center: true
  fill INK
  @brush_dots = BRUSHES.each_with_index.map do |size, i|
    x = 510 + i * 34
    dot = oval x, BAR / 2, size, center: true, cursor: :hand_cursor
    dot.click { choose_brush(size, x) }
  end

  pill("Undo", 610) { undo }
  pill("Clear", 682) do
    @ink.clear
    @strokes = []
  end

  click { |_button, x, y| start_stroke(x, y) if y > BAR }
  motion { |x, y| extend_stroke(x, y) if @stroke }
  release { end_stroke }

  keypress do |key|
    undo if key == :alt_z || key == :control_z
  end
end
