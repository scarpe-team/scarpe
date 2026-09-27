# Starfield: 420 stars in three layers drifting at sixty frames a second.
#
# Near stars move faster than far ones, which is what makes it look deep.
# Move the mouse to look around. The corner shows the frame rate as measured.

WIDTH, HEIGHT = 800, 500

# far to near: how many, how big, how bright, how fast (px a second),
# and how far the layer shifts when you look around
LAYERS = [
  { count: 260, sizes: [1, 2], alpha: 0.35..0.7, speed: 8, shift: 6 },
  { count: 120, sizes: [2, 3], alpha: 0.6..0.9, speed: 26, shift: 16 },
  { count: 40, sizes: [3, 4], alpha: 0.85..1.0, speed: 70, shift: 40 },
]
TINTS = [[255, 255, 255], [214, 228, 255], [255, 240, 214], [196, 214, 255]]

Star = Struct.new(:layer, :x, :y, :dot, :glow, :shown_x, :shown_y)

Shoes.app(title: "Starfield", width: WIDTH, height: HEIGHT, resizable: false) do
  def make_star(layer)
    size = layer[:sizes].sample
    tint = TINTS.sample
    star = Star.new(layer, rand(WIDTH).to_f, rand(HEIGHT).to_f)
    star.glow = oval(0, 0, size * 3, center: true, fill: rgb(*tint, 0.12)) if layer == LAYERS.last
    star.dot = oval(0, 0, size, center: true, fill: rgb(*tint, rand(layer[:alpha])))
    star
  end

  # Moves a star at its layer's speed and shifts it by where you are looking,
  # wrapping round the edges. Most frames a far star stays on the same pixel,
  # so it only tells the renderer when that pixel changes.
  def drift(star, seconds)
    layer = star.layer
    star.x = (star.x - layer[:speed] * seconds) % WIDTH
    x = ((star.x + @view[0] * layer[:shift]) % WIDTH).round
    y = ((star.y + @view[1] * layer[:shift]) % HEIGHT).round
    if x != star.shown_x
      star.dot.left = x
      star.glow&.left = x
      star.shown_x = x
    end
    if y != star.shown_y
      star.dot.top = y
      star.glow&.top = y
      star.shown_y = y
    end
  end

  # Now and then a shooting star: a bright head with a fading tail.
  def fly_meteor(seconds)
    @meteor = new_meteor if @meteor.nil? && rand < seconds / 5.0 # about once every five seconds
    return unless @meteor

    @meteor[:age] += seconds
    @meteor[:x] -= 520 * seconds
    @meteor[:y] += 190 * seconds
    x, y = @meteor[:x], @meteor[:y]
    @trail.zip([140, 70, 24]).each do |streak, length|
      streak.style(left: x, top: y, x2: x + length, y2: y - length * 0.365, hidden: false)
    end
    return unless @meteor[:age] > 0.9 || x < 20

    @trail.each(&:hide)
    @meteor = nil
  end

  # It starts off to the right and falls left, never so high that its tail leaves the sky.
  def new_meteor
    { x: rand(500..WIDTH + 100).to_f, y: rand(70..170).to_f, age: 0.0 }
  end

  # Every thirty frames, how many frames a second those thirty took.
  def count_frame(now)
    @frames += 1
    return if @frames < 30

    show_fps((@frames / (now - @since)).round)
    @frames = 0
    @since = now
  end

  def show_fps(fps)
    @fps.replace strong("#{fps} fps", stroke: white), span("  ·  #{@stars.size} stars", stroke: rgb(255, 255, 255, 0.55))
  end

  background "#060a1c".."#24154a", angle: 35

  @view = [0.0, 0.0] # where you are looking, from -1 to 1 each way
  @look = [0.0, 0.0]
  nostroke
  @stars = LAYERS.flat_map { |layer| Array.new(layer[:count]) { make_star(layer) } }

  cap :curve
  @trail = [[1, 0.18], [2, 0.35], [3, 0.9]].map do |width, alpha|
    strokewidth width
    stroke rgb(255, 255, 255, alpha)
    line(0, 0, 0, 0, hidden: true)
  end

  stack left: WIDTH - 162, top: 18, width: 144, height: 30 do
    background rgb(255, 255, 255, 0.08), curve: 15
    @fps = para "", align: "center", size: 12, margin_top: 7
  end
  show_fps "--"
  stack left: 22, top: HEIGHT - 40, width: 400 do
    para "Move the mouse to look around.", size: 12, stroke: rgb(255, 255, 255, 0.4)
  end

  motion do |x, y|
    @look = [(x - WIDTH / 2.0) / (WIDTH / 2.0), (y - HEIGHT / 2.0) / (HEIGHT / 2.0)]
  end

  @frames = 0
  @since = @then = Time.now
  animate(60) do
    now = Time.now
    seconds = [now - @then, 0.1].min
    @then = now
    @view = @view.zip(@look).map { |view, look| view + (look - view) * 0.06 }
    @stars.each { |star| drift(star, seconds) }
    fly_meteor(seconds)
    count_frame(now)
  end
end
