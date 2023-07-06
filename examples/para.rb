# if this example path is changed from examples/para.rb update in docs too

Shoes.app do
  para_widget = para "Hello, This is title!", stroke: "red", size: :title, font: "Arial"
  @btn = button "toogle title🪄" ,color:"#FF7116",padding_bottom:"8",padding_top:"8",text_color:"white"

  toggle = true

  @btn.click do
    toggle = !toggle
    if toggle
      para_widget.show
    else
      para_widget.hide
    end
  end

  @btn2 = button "replace title🪄" ,color:"#FF7116",padding_bottom:"8",padding_top:"8",text_color:"white"

  @btn2.click do
    para_widget.replace("Welcome!")
  end

  banner_widget = banner("Welcome to Shoes!")
  title_widget = title("Shoes Examples")
  subtitle_widget = subtitle("Explore the Features")
  tagline_widget = tagline("Step into a World of Shoes")
  caption_widget = caption("A GUI Framework for Ruby")
  inscription_widget = inscription("Designed for Easy Development")

end
