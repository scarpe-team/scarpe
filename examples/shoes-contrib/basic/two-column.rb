Shoes.app do
  flow do
    stack :width => 200 do
      caption "Column one"
      para "is 200 pixels wide"
    end
    stack :width => -200 do
      caption "Column two"
      para "is 100% minus 200 pixels wide"
    end
  end
end
