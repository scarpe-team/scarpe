Shoes.app do
  edit_box do |e|
    @counter.text = e.text.size
  end
  @counter = strong("0")
  para @counter, " characters"
end
