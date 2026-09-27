# Turns add up, as in Shoes 3 (ledger E10): each rotate turns the pen further, so the
# shapes below sit at 90, 180, 60, 120, 75, 45 and 180 degrees.
Shoes.app(height:600) do
  rotate 90
  rect 10, 10, 75, 50, 5
  rotate 90
  arrow 100, 100, 30
  rotate(-120)
  arrow 150, 120,40
  rotate 60
  arrow 30 ,60 ,40
  rotate(-45)
  arc 50, 50, 120, 100, 60, 225
  rotate(-30)
  arrow :left => 50, :top => 80,
    :width => 40
  rotate 135
  line 100, 100, 200, 200
end
