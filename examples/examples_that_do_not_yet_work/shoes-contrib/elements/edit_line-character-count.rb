Shoes.app do
  edit_line do |e|
    @counter.text = e.text.size
  end
  @counter = strong("0")
  para @counter, " characters"
end
