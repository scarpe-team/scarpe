# 500 translucent ovals drifting under animate(60): the frame-rate benchmark in native/PERF.md.
# Each frame moves every oval, so the whole window changes every frame.
Shoes.app(title: "500 ovals", width: 600, height: 500) do
  background "#fbfbfd"

  # A triangle wave, so an oval bounces between 0 and max whatever the frame number.
  bounce = ->(v, max) { v %= 2 * max; v > max ? 2 * max - v : v }

  srand(500)
  dots = Array.new(500) do
    size = rand(8..24)
    fill rgb(rand(40..220), rand(40..220), rand(40..220), 0.7)
    nostroke
    [oval(0, 0, size), rand(600.0), rand(500.0), rand(-3.0..3.0), rand(-3.0..3.0), 600 - size, 500 - size]
  end

  animate(60) do |frame|
    dots.each do |dot, x, y, vx, vy, max_x, max_y|
      dot.move(bounce.(x + vx * frame, max_x).round, bounce.(y + vy * frame, max_y).round)
    end
  end
end
