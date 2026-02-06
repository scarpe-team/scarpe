Shoes.app do
  @p = para
  animate do
    button, left, top = self.mouse
    @p.replace "mouse: #{button}, #{left}, #{top}"
  end
end
