# After a list box is used with the mouse, it keeps keyboard focus without
# showing it, and takes the keys an app listens for: Space opens its popup and
# Up and Down change its choice, so the app's keypress block never hears them.
#
# Choose an item with the mouse, then press Space. Expected: the para counts
# the Space, as it does before the list box is touched (on macOS a pop-up
# button does not take focus from a click unless Full Keyboard Access is on).
# Actual: nothing counts, the popup opens again, and no focus ring shows why.
#
#   scarpe peek _repros/bloop_sequencer_1.rb --key " " --click "Two" --click "Three" --key " " --layout
#   expected: "spaces: 2"   actual: "spaces: 1"

Shoes.app(title: "Space after a list box", width: 260, height: 160) do
  @spaces = 0
  @count = para "spaces: 0", margin: 10
  list_box items: %w[One Two Three], choose: "Two", margin: 10
  keypress do |key|
    next unless key == " "

    @spaces += 1
    @count.replace "spaces: #{@spaces}"
  end
end
