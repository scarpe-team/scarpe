# Test input focus control
Shoes.app(title: "Focus Test", width: 350, height: 250) do
  stack margin: 10 do
    para "Click buttons to focus different inputs:"
    
    @el1 = edit_line text: "First field"
    @el2 = edit_line text: "Second field"
    @eb = edit_box text: "Text area"
    
    flow do
      button "Focus First" do
        @el1.focus
      end
      
      button "Focus Second" do
        @el2.focus
      end
      
      button "Focus TextArea" do
        @eb.focus
      end
    end
  end
end
