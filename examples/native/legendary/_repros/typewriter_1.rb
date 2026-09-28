# A press on a drawable with no click block should pass to the topmost drawable
# under the pointer that has one (DESIGN 4.3: "the innermost such id under the
# pointer"; ledger E8: "routes a press to the topmost drawable with has_click";
# Shoes 3 skips elements without a click proc in shoes_canvas_send_click2).
#
# Here a label sits on an oval that counts clicks. Clicking the oval below the
# word counts; clicking the word itself should count too, and on the native
# display it does nothing: hit_test returns the para, and the press only looks
# for has_click among the para's own ancestors, never at the oval beneath it.
#
#   scarpe peek _repros/typewriter_1.rb --click-at 100,86 --click-at 100,60 --layout
#   expected: "clicked 2"   actual: "clicked 1"

Shoes.app(title: "Click through a label", width: 200, height: 120) do
  @count = 0
  @oval = oval 100, 60, 80, center: true, fill: orange
  stack left: 60, top: 53, width: 80 do
    @label = para "click me", align: "center", size: 12, margin: 0
  end
  @oval.click do
    @count += 1
    @label.replace "clicked #{@count}"
  end
end
