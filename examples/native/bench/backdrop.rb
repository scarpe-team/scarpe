# One small ball bouncing over a busy, still window (an image background, a page of text, a few
# controls): the partial-repaint benchmark in native/PERF.md. Almost nothing changes per frame.
Shoes.app(title: "Backdrop", width: 600, height: 500) do
  background File.expand_path("../../../docs/image.png", __dir__)
  stack(margin: 20) do
    background rgb(255, 255, 255, 0.85), curve: 12
    title "Nothing to see here"
    8.times { |i| para "Line #{i + 1} of a page of text that stays exactly where it is while the ball moves." }
    flow do
      button "OK"
      button "Cancel"
      edit_line "still"
    end
  end
  fill red
  nostroke
  @ball = oval(0, 0, 24)
  animate(60) do |frame|
    x = (frame * 4) % 1100
    @ball.move(x > 550 ? 1100 - x : x, 400 + (Math.sin(frame / 9.0) * 40).round)
  end
end
