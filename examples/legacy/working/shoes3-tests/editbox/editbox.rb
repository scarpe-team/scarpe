Shoes.app height: 500, width: 300 do
  stack do
    flow do
      para "Normal "
       @eb1 = edit_box "Normal", tooltip: "normal"
    end
    flow do 
      para "Font  "
      @eb2 = edit_box "Font Is?", font: "Monaco 9", tooltip: "monaco 9",
         width: 300
    end
    flow do
      para "Stroke "
      @eb3 = edit_box "Stroke", stroke: red, tooltip: "red"
    end
    flow do
      para "Both   "
      @eb4 = edit_box "Font and Stroke", font: "Monaco 14", stroke: green,
        tooltip: "14pt fixed & green"
    end
    flow do
      button "Append to" do
        @eb1.append "\nAppended"
        @eb2.append "\nAppended"
        @eb3.append "\nAppended"
        @eb4.append "\nAppended"
      end
      button "change all" do
        @eb1.text = "I've been reset1"
        @eb2.text = "I've been reset1"
        @eb3.text = "I've been reset1"
        @eb4.text = "I've been reset1"
      end
    end
  end
end
