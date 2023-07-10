Shoes.app do
  para "Manuscript:"
  lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim."
  @manuscript = edit_box(lorem, width: "100%") do |box|
    @char_count.replace("#{box.text.length} characters")
  end
  @char_count = para "#{@manuscript.text.length} characters"
end
