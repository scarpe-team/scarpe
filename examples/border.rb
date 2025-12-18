Shoes.app(width: 300, height: 50) do
  stack height: 50 do
    para "Border is on top of text"
    border yellow, strokewidth: 4
  end

  stack do
    para "This border is also on top of text"
    border blue, strokewidth: 4
  end
end
