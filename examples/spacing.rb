Shoes.app(title: "Spacing") do
  stack margin: 50 do
    background "purple"
    para "with 50px margin", stroke: "white"
  end
  stack margin: { left: 10, right: 10, bottom: 20 } do
    background "red"
    para "with 10px margin-left and margin-right, and 20px margin-bottom", stroke: "white"
  end
  stack margin: [15, 15, nil, 40] do
    background "blue"
    para "with 15px margin-left and margin-right, and 40px margin-bottom", stroke: "white"
  end
  stack margin_left: 20, margin_right: 30, margin_bottom: 10 do
    background "green"
    para "with 20px margin-left, 30px margin-right, and 10px margin-bottom", stroke: "white"
  end
end
