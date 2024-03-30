Shoes.app height: 300, width: 300 do
  stack do
    flow do
      para "Normal "
       @el1 = edit_line "Normal", tooltip: "Normal"
    end
    flow do 
      para "Font  "
      @el2 = edit_line "Font Is?", font: "Monaco 9", tooltip: "monaco 9"
    end
    flow do
      para "Stroke "
      @el3 = edit_line "Stroke", stroke: red, tooltip: "red"
    end
    flow do
      para "Both"
      @el4 = edit_line "Stroke and Font", stroke: green, font: "Arial 14",
       tooltip: "green arial 14"
    end
    button "change contents" do
      @el1.text = "Changed!"
      @el2.text = "Changed!"
      @el3.text = "Changed!"
      @el4.text = "Changed!"
    end
  end
end
