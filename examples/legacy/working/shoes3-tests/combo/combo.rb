Shoes.app height: 200, width: 300 do
  stack do
    flow do
      para "Normal "
      list_box :items => ["one", "two", "three"], choose: "two", tooltip: 
        "normal combo"
    end
    flow do 
      para "Font  "
      list_box items: ["Alpha", "Bravo", "Charlie"], font: "Monaco 9",
        choose: "Bravo", tooltip: "monaco 9 font"
    end
    flow do
      para "Stroke "
      list_box items: ["Ask", "your", "mother!"], choose: "your", stroke: red,
        tooltip: "stroke red"
    end
    flow do
      para "Both  "
      list_box items: ["Quoth", "the", "Raven"], font: "Helvitica Italic 16", stroke: blue,
        tooltip: "blue Helvetica Italic 16", choose: "Quoth"
    end
  end
end
