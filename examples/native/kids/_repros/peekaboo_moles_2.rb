# Repro: a nested slot's left and top answer the numbers it was given, not
# where it is in the window.
#
# docs/native.md says, under Known gaps, that "left and top answer in window
# coordinates, where Shoes 3 answers from the parent's content origin". For a
# slot placed with left: and top: inside another placed slot they answer the
# numbers it was given instead, which are from the parent's corner:
#
#   @inner.left, @inner.top   => 60, 40
#   layout (peek --layout)    => #4 Stack 160,90 80x50
#
# while something flowed into the same slot answers in window coordinates (a
# para there answers 100, 50, its margin box's corner). So one app can get
# both kinds of answer, and hit-testing a button inside a card by its left and
# top misses it: that is how Peekaboo Moles found it. Either answer would do if
# every drawable gave the same kind; the docs should say which.
#
#   bundle exec ruby exe/scarpe peek examples/native/kids/_repros/peekaboo_moles_2.rb --layout
Shoes.app(width: 400, height: 300) do
  @outer = stack(left: 100, top: 50, width: 200, height: 200) do
    @inner = stack(left: 60, top: 40, width: 80, height: 50) { background red }
    @word = para "flowed"
  end
  every(0.1) { @report.replace("inner #{@inner.left},#{@inner.top}   para #{@word.left},#{@word.top}") }
  @report = para "", left: 10, top: 270, size: 10
end
