Shoes.app :width => 320, :height => 420 do
  stack :margin => 40 do
    stack :margin => 10 do
      para "Name"
      @name = list_box :items => ["Phyllis", "Ronald", "Wyatt"]
    end
  end
end
