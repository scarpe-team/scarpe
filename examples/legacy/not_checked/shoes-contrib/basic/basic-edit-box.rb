Shoes.app do
  stack :margin => 10 do
    @edit = edit_box :width => 1.0 do
      @para.text = @edit.text
    end
    @para = para ""
  end
end
