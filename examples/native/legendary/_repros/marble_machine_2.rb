# Repro (performance): Drawable#style rebuilds the class's style names on every call.
#
# An animation moves its shapes with style(left:, top:) every frame, so the cost of
# one call sets how many shapes can move at sixty frames a second. Lacci's
# Drawable#style starts with `self.class.shoes_style_names`, which walks the class
# chain and builds fresh arrays each time (drawable.rb, `def style`), and only then
# looks at the two keys it was given.
#
# Run it headless:  scarpe peek examples/native/legendary/_repros/marble_machine_2.rb
# Expected: shoes_style_names is looked up once per class, so it costs nothing per call.
# Actual (M5, 28 Sep 2026, a busy machine): a style call takes 9 to 13 us, and 3.5 to
#           4.2 us of it is shoes_style_names; the event bus takes about 4 us more and the
#           shim 3.3 us. Marble Machine spends 4 of its 5.6 ms of Ruby a frame in style calls.
Shoes.app(title: "Style cost", width: 360, height: 120) do
  nostroke
  dot = oval(100, 60, 10, center: true, fill: red)
  @report = para "measuring..."
  timer(0.2) do
    cpu = -> { Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) }
    n = 20_000
    t = cpu.()
    n.times { |i| dot.style(left: 100 + (i % 7) * 0.1, top: 60.5) }
    style = (cpu.() - t) / n * 1e6
    t = cpu.()
    n.times { Shoes::Oval.shoes_style_names }
    names = (cpu.() - t) / n * 1e6
    line = format("style: %.1f us a call, shoes_style_names alone: %.1f us", style, names)
    puts line
    @report.replace line
  end
end
