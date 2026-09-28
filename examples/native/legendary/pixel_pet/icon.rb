# Pixel Pet's icon: the pet's happiest face on its little screen.
# Rendered at 2x from this 256x256 window, once on black and once on white
# (ICON_BACKDROP), so the icon and its shadow lift off cleanly.

FACE = <<~ART.lines(chomp: true)
  ..oo........oo..
  .o#po......op#o.
  .o#ppo....opp#o.
  .o###oooooo###o.
  o##############o
  o##############o
  o####e####e####o
  o###e#e##e#e###o
  o##############o
  o#pp##m##m##pp#o
  o######mm######o
  o##############o
  os############so
  .os##########so.
  ..oosssssssssoo.
ART
PAINT = { "o" => "#4a3b52", "#" => "#fff6ee", "s" => "#f1d9cb", "p" => "#ff9ebb", "e" => "#2d2433", "m" => "#8a2846" }

Shoes.app(title: "Pixel Pet icon", width: 256, height: 256, resizable: false) do
  background ENV.fetch("ICON_BACKDROP", "white")
  nostroke
  4.times { |i| rect 24 - i, 30 + i * 2, 208 + i * 2, 208 + i, curve: 46 + i, fill: rgb(120, 40, 80, 0.06) }
  rect 24, 24, 208, 208, curve: 46, fill: "#ffd9e7".."#ffadc9"
  rect 48, 48, 160, 160, curve: 26, fill: "#fff0f5"
  rect 56, 56, 144, 144, curve: 18, fill: "#dfe9cf"
  FACE.each_with_index do |line, y|
    line.each_char.with_index do |letter, x|
      rect 64 + x * 8, 69 + y * 8, 7, 7, fill: PAINT[letter] if PAINT[letter]
    end
  end
end
