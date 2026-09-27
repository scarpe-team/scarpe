# Snake: steer with the arrow keys, eat the apples, don't bite yourself.
#
# Space starts again after a crash, P pauses. It speeds up as you grow.

COLS, ROWS, CELL = 20, 16, 26
BOARD_X, BOARD_Y = 20, 84 # the board's top left corner in the window
HEAD = [126, 224, 160]
TAIL = [38, 140, 150]
CORAL = "#ff6b5b"
TURNS = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] }
KEYS = { :up => :up, :down => :down, :left => :left, :right => :right,
         "w" => :up, "s" => :down, "a" => :left, "d" => :right }

Shoes.app(title: "Snake", width: 560, height: 540, resizable: false) do
  # Where a cell is on the window.
  def at(x, y)
    [BOARD_X + x * CELL, BOARD_Y + y * CELL]
  end

  # Head colour fading to tail colour along the body.
  def shade(i, length)
    t = length > 1 ? i.to_f / (length - 1) : 0
    rgb(*HEAD.zip(TAIL).map { |head, tail| (head + (tail - head) * t).round })
  end

  def new_game
    @cells = [[6, 8], [5, 8], [4, 8]] # head first
    @heading = :right
    @turns = []
    @score = 0
    @over = false
    @waiting = true
    @paused = false
    @pieces.each(&:remove)
    @pieces = []
    @cells.each { add_piece }
    place_apple
    paint_snake
    @score_text.replace "0"
    @overlay.hide
    @hint_text.replace "Press an arrow key to start"
    @hint.show
    run_every 0.14
  end

  # The body lives in its own slot, under the eyes.
  def add_piece
    @body.append { @pieces << rect(0, 0, CELL - 2, CELL - 2, curve: 8) }
  end

  # The snake's pieces follow its cells, head first, shaded head to tail.
  def paint_snake
    @pieces.zip(@cells).each_with_index do |(piece, (x, y)), i|
      left, top = at(x, y)
      piece.style(left: left + 1, top: top + 1, fill: shade(i, @cells.size))
    end
    paint_eyes
  end

  # Two eyes on the head, looking the way it goes.
  def paint_eyes
    dx, dy = TURNS[@heading]
    left, top = at(*@cells.first)
    cx, cy = left + CELL / 2 + dx * 4, top + CELL / 2 + dy * 4
    [-1, 1].each_with_index do |side, i|
      ex, ey = cx + dy * side * 5, cy + dx * side * 5
      @eyes[i * 2].move(ex, ey)
      @eyes[i * 2 + 1].move(ex + dx * 1.5, ey + dy * 1.5)
    end
  end

  def place_apple
    free = (0...COLS).to_a.product((0...ROWS).to_a) - @cells
    @apple = free.sample
    left, top = at(*@apple)
    @apple_parts.each { |part, dx, dy| part.move(left + dx, top + dy) }
  end

  def run_every(seconds)
    @clock&.remove
    @clock = every(seconds) { step unless @waiting || @over || @paused }
  end

  def turn(way)
    last = @turns.last || @heading
    opposite = TURNS[way].zip(TURNS[last]).all? { |a, b| a == -b }
    @turns << way unless way == last || opposite || @turns.size > 2
    @waiting = false
    @hint.hide unless @paused
  end

  def toggle_pause
    @paused = !@paused
    @hint_text.replace "Paused, P to carry on"
    @paused ? @hint.show : @hint.hide
  end

  def step
    @heading = @turns.shift || @heading
    dx, dy = TURNS[@heading]
    head = [@cells.first[0] + dx, @cells.first[1] + dy]
    return crash if head[0] < 0 || head[0] >= COLS || head[1] < 0 || head[1] >= ROWS
    return crash if @cells[0..-2].include?(head)

    @cells.unshift(head)
    if head == @apple
      @score += 1
      @best = [@best, @score].max
      @score_text.replace @score.to_s
      @best_text.replace "best #{@best}"
      add_piece
      place_apple
      run_every [0.14 - @score * 0.004, 0.07].max # a little faster with every apple
    else
      @cells.pop
    end
    paint_snake
  end

  def crash
    @over = true
    @final.replace "#{@score} #{@score == 1 ? "apple" : "apples"}"
    @overlay.show
  end

  background "#10141d".."#1a2030"

  # the header: name on the left, score on the right
  stack left: BOARD_X, top: 22, width: 200 do
    para "Snake", size: 22, weight: "bold", stroke: white, margin: 0
    para "arrows steer, space restarts, P pauses", size: 11, stroke: "#7d8799", margin: [0, 3, 0, 0]
  end
  stack left: 340, top: 16, width: 200 do
    @score_text = para "0", align: "right", size: 30, weight: "bold", stroke: white, margin: 0
    @best_text = para "best 0", align: "right", size: 11, stroke: "#7d8799", margin: 0
  end

  # the board, with every other tile a shade lighter
  nostroke
  fill "#172030"
  rect BOARD_X - 6, BOARD_Y - 6, COLS * CELL + 12, ROWS * CELL + 12, curve: 16
  fill "#1b2536"
  COLS.times do |x|
    ROWS.times do |y|
      rect(*at(x, y).map { |v| v + 1 }, CELL - 2, CELL - 2, curve: 5) if (x + y).odd?
    end
  end

  # the apple: a coral fruit, a leaf and a glint of light
  @apple_parts = [
    [oval(0, 0, 20, fill: CORAL), 3, 4],
    [oval(0, 0, 9, 5, fill: "#6fd08c"), 12, 1],
    [oval(0, 0, 5, fill: rgb(255, 255, 255, 0.55)), 7, 8],
  ]

  @pieces = []
  @body = stack(left: 0, top: 0, width: 560, height: 540) { nostroke } # the snake, drawn without outlines
  @eyes = 2.times.flat_map { [oval(0, 0, 7, center: true, fill: white), oval(0, 0, 3, center: true, fill: "#10141d")] }

  @hint = stack left: BOARD_X + COLS * CELL / 2 - 110, top: BOARD_Y + ROWS * CELL / 2 + 36, width: 220, height: 34 do
    background rgb(10, 13, 20, 0.7), curve: 17
    @hint_text = para "", align: "center", size: 13, stroke: rgb(255, 255, 255, 0.85), margin_top: 8
  end

  @overlay = stack left: BOARD_X - 6, top: BOARD_Y - 6, width: COLS * CELL + 12, height: ROWS * CELL + 12, hidden: true do
    background rgb(10, 13, 20, 0.78), curve: 16
    para "Game over", align: "center", size: 30, weight: "bold", stroke: white, margin: [0, 150, 0, 0]
    @final = para "", align: "center", size: 15, stroke: "#9aa4b5", margin: [0, 6, 0, 0]
    again = stack(left: (COLS * CELL + 12) / 2 - 70, top: 270, width: 140, height: 42) do
      background CORAL, curve: 21
      para "Play again", align: "center", size: 14, weight: "semibold", stroke: white, margin_top: 11
    end
    again.click { new_game }
  end

  @best = 0
  keypress do |key|
    if KEYS[key]
      turn KEYS[key] unless @over
    elsif key == " " && @over
      new_game
    elsif key == "p" && !@waiting && !@over
      toggle_pause
    end
  end

  new_game
end
