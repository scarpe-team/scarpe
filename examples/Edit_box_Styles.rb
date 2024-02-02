Shoes.app do
    para "Anything:",size:"30px"
    lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim."
    @manuscript = edit_box(lorem, width: "100%", font:"italic normal bold 25px 'Times New Roman', serif;", tooltip:"This is a tooltip") do |box|
      @char_count.replace("#{box.text.length} characters")
    end
    @char_count = para "#{@manuscript.text.length} characters" ,size:"20px"
  end