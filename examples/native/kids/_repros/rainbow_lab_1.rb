# Repro (Rainbow Lab, Maze Mouse): an empty slot laid over a clickable one fools the
# automation path, though a real click goes through it.
#
# A real press goes to the topmost drawable under the pointer that has a click block
# (DESIGN 4, ledger E8), so an empty slot with no block lets the press through to the red
# box beneath it. The automation click in native/src/automation.rs asks input::hit_test for
# the topmost node of any kind instead, and uses that answer twice:
#
#   scarpe peek examples/native/kids/_repros/rainbow_lab_1.rb --click-at 60,60 --layout
#     prints "click 60.0,60.0 -> #7", the empty slot, while the para reads
#     "the red box got the click": the reported hit is not the drawable whose block ran
#
#   scarpe peek examples/native/kids/_repros/rainbow_lab_1.rb --click "Tap me"
#     refuses: "5 is covered by Stack 7", and in a Shoes-Spec case click_on(stack("@box"))
#     raises the same AutomationError, though click_at on the same point works
#
# Expected: the reported hit is the drawable whose block runs, and a targeted click is
# refused only when something that would take the press (a control, or a drawable with a
# click block) covers the target. Rainbow Lab and Maze Mouse keep full-window empty stacks
# above their pots and arrow pads for drops, sparkles and paw prints to fly in, so their
# checks click by position (click_at) rather than click_on.

Shoes.app(title: "Empty overlay", width: 240, height: 130) do
  @box = stack(left: 20, top: 20, width: 90, height: 90) do
    background "#e53935"
    para "Tap me", stroke: white, margin: [14, 34, 0, 0]
  end
  @box.click { @said.replace "the red box got the click" }
  stack(left: 0, top: 0, width: 240, height: 130) {} # an empty layer on top, with no click block
  @said = para "nothing yet", left: 120, top: 52, width: 110, size: 10
end
