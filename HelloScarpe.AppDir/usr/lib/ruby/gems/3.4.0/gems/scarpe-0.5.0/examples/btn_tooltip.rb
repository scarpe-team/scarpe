Shoes.app do
  @btn = button "who am i?", :tooltip => "i have no idea either"
  @para = para "i am a button"
  @btn.hover do
    @para.replace "i am a button and i am being hovered"
  end
end
