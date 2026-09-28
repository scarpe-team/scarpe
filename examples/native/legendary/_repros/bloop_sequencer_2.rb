# One press, one click block. A slot's click is a SubscriptionItem that fires for
# any press inside the slot's box, so when two clickable slots overlap (one nested
# in the other, or a sibling drawn on top) a single press runs both blocks. Shoes 3
# hands the press to the first element, innermost and topmost first, whose click
# block takes it (shoes_canvas_send_click2 returns at the first), and DESIGN 4.3
# says "the innermost such id under the pointer".
#
#   scarpe peek _repros/bloop_sequencer_2.rb --click "arrow" --click "sibling" --layout
#   expected: "card 0, arrow 1, sibling 1"   actual: "card 2, arrow 1, sibling 1"

Shoes.app(title: "One press, one click", width: 300, height: 170) do
  @counts = Hash.new(0)
  def count(name)
    @counts[name] += 1
    @label.replace %w[card arrow sibling].map { |n| "#{n} #{@counts[n]}" }.join(", ")
  end

  @label = para "card 0, arrow 0, sibling 0", margin: 10
  card = stack(left: 10, top: 40, width: 280, height: 50) do
    background "#dde4ff"
    arrow = stack(left: 230, top: 8, width: 40, height: 34) do
      background "#7aa2ff"
      para "arrow", size: 9, margin: 4
    end
    arrow.click { count("arrow") }
  end
  card.click { count("card") }

  plate = stack(left: 10, top: 100, width: 280, height: 50) { background "#ffe0d6" }
  plate.click { count("card") }
  sibling = stack(left: 240, top: 108, width: 44, height: 34) do # drawn on top of the plate, not inside it
    background "#ff8a65"
    para "sibling", size: 9, margin: 4
  end
  sibling.click { count("sibling") }
end
