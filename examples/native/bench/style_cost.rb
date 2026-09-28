# What one style call costs (a bench, from the Marble Machine lane).
#
# An animation moves its shapes with style(left:, top:) every frame, so the cost of
# one call sets how many shapes can move at sixty frames a second. Lacci's
# Drawable#style starts with `self.class.shoes_style_names`, which used to walk the
# class chain and build fresh arrays on every call; since 28 Sep 2026 each class keeps
# its list until a new style is declared.
#
# Run it headless:  scarpe peek examples/native/bench/style_cost.rb
# M5, 28 Sep 2026, a quiet machine: 8.1 to 8.6 us a call before the names were kept
# (2.9 to 3.4 us of it in shoes_style_names), 5.3 to 5.6 us after (0.2 us). The rest
# is the event bus and the shim.
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
