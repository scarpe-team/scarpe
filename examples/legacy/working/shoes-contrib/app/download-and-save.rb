Shoes.app do
  stack do
    title "Downloading Google image", :size => 16
    @status = para "One moment..."

    download "http://shoesrb.com/images/shoes-icon.png", 
      :save => "shoes-icon.png" do
        @status.text = "Okay, is downloaded."
    end
  end
end
