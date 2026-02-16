# Demo: Shape with curve_to (Bézier curves)
# This was previously missing from Scarpe — now shapes can draw smooth curves.
Shoes.app :width => 400, :height => 400, :title => "Shape Curves Demo" do
  background "#333"

  stack :margin => 15 do
    title "Shape Curves", :stroke => white

    # A heart shape using Bézier curves
    shape do
      move_to(200, 140)
      curve_to(200, 120, 160, 80, 130, 80)
      curve_to(70, 80, 70, 140, 70, 140)
      curve_to(70, 180, 130, 220, 200, 280)
      curve_to(270, 220, 330, 180, 330, 140)
      curve_to(330, 140, 330, 80, 270, 80)
      curve_to(240, 80, 200, 120, 200, 140)
    end
  end
end
