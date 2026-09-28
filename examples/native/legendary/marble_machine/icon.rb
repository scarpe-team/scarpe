# Marble Machine's icon: glass marbles tumbling through brass pins into tubes.
# Rendered at 2x from this 256x256 window, once on black and once on white
# (ICON_BACKDROP), so the icon and its shadow lift off cleanly.

BRASS = ["#ffe7a6", "#b98231"]

Shoes.app(title: "Marble Machine icon", width: 256, height: 256, resizable: false) do
  def mix(color, other, amount)
    color.zip(other).map { |c, o| (c + (o - c) * amount).round }
  end

  def marble(x, y, size, color)
    nostroke
    oval x, y + size * 0.08, size, center: true, fill: rgb(0, 0, 0, 0.3)
    oval x, y, size, center: true, fill: gradient(rgb(*mix(color, [255, 255, 255], 0.45)), rgb(*mix(color, [10, 10, 30], 0.35)), angle: 35)
    oval x - size * 0.18, y - size * 0.2, size * 0.28, center: true, fill: rgb(255, 255, 255, 0.85)
  end

  def tail(x, y, dx, dy, size, color)
    nostroke
    6.times do |i|
      t = (i + 1) / 6.0
      oval x - dx * t, y - dy * t, size * (1 - t * 0.75), center: true, fill: rgb(*color, 0.32 * (1 - t))
    end
  end

  def pin(x, y)
    nostroke
    oval x, y + 1.5, 11, center: true, fill: rgb(0, 0, 0, 0.35)
    oval x, y, 10, center: true, fill: gradient(*BRASS, angle: 35)
    oval x - 1.5, y - 1.8, 3, center: true, fill: rgb(255, 255, 255, 0.85)
  end

  background ENV.fetch("ICON_BACKDROP", "white")
  nostroke
  4.times { |i| rect 24 - i, 30 + i * 2, 208 + i * 2, 208 + i, curve: 46 + i, fill: rgb(20, 10, 40, 0.07) }
  rect 24, 24, 208, 208, curve: 46, fill: gradient("#14243a", "#2a1a3f", angle: 25)
  rect 30, 30, 60, 196, curve: 40, fill: gradient(rgb(255, 255, 255, 0.07), rgb(255, 255, 255, 0), angle: 90)

  # a Galton triangle of pins
  [[128, 96], [106, 122], [150, 122], [84, 148], [128, 148], [172, 148]].each { |x, y| pin(x, y) }

  # five tubes, with a little bell of marbles already in them
  (0..5).each { |i| rect 48 + i * 32 - 1.5, 166, 3, 44, fill: gradient(*BRASS, angle: 90) }
  rect 45, 208, 166, 5, curve: 2, fill: gradient(*BRASS, angle: 0)
  jewels = [[233, 69, 96], [255, 187, 64], [46, 196, 226], [150, 104, 245], [38, 196, 141], [255, 126, 95]]
  piles = [1, 3, 5, 3, 1]
  piles.each_with_index do |count, tube|
    middle = 64 + tube * 32
    count.times do |n|
      row, place = n < 2 ? [0, n] : n < 3 ? [1, 0] : [2, n - 3]
      x = row == 1 ? middle : middle - 7 + place * 14
      x = middle if count == 1
      marble(x, 200 - row * 11.5, 13, jewels[(tube * 2 + n) % jewels.size])
    end
  end

  # and three marbles on their way down
  tail(118, 66, -14, 30, 26, jewels[0])
  marble(118, 66, 26, jewels[0])
  tail(161, 106, -10, 22, 18, jewels[2])
  marble(161, 106, 18, jewels[2])
  tail(93, 131, 8, 20, 16, jewels[1])
  marble(93, 131, 16, jewels[1])
end
