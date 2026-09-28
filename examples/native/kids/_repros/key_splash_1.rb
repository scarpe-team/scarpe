# Repro (Key Splash): a press on a clickable slot also fires a clickable shape underneath it,
# and the shape fires first.
#
# The white box is drawn after the grey rect, so it sits on top, and it has a click block.
# Shoes 3's shoes_canvas_send_click2 walks the canvas top down and stops at the first element
# with a click block, so a press on "Click me" should run the box's block and nothing else.
# Here the grey rect's block runs too, and before the box's: the rect is "the topmost drawable
# with has_click" (native/src/input.rs pointer_owner, ledger E8), and the box's click is a
# SubscriptionItem that fires for any press inside its slot (DESIGN 4.3). If the rect's block
# removes the box (a modal's backdrop closing the modal, as Key Splash's name card did), the
# box's block never runs at all.
#
#   bundle exec ruby exe/scarpe peek examples/native/kids/_repros/key_splash_1.rb --click "Click me" --layout
#
# expected: the last line says "box"
# actual:   it says "rect, box"
Shoes.app(title: "Repro: slot over shape", width: 300, height: 200) do
  @heard = []
  under = rect(0, 0, 300, 200, fill: gray(0.85))
  under.click { @heard << "rect"; @said.replace @heard.join(", ") }
  box = stack(left: 50, top: 40, width: 200, height: 80) do
    background white
    para "Click me", align: "center", margin_top: 30
  end
  box.click { @heard << "box"; @said.replace @heard.join(", ") }
  @said = para "nobody yet", left: 10, top: 160
end
