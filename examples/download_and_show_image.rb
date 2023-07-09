Shoes.app do
  stack do
    title "Downloading Google image", size: 16
    @status = para "Enter URL and press Enter:"
    @download_completed = false

    url_edit = edit_line
    caption "here is a cute cat url: https://img.freepik.com/premium-photo/funny-smart-cat-professor-with-glasses-illustration-generative-ai_845977-709.jpg?w=700&h=300"

    button 'Download Image!',color:"#3d5a80",padding_bottom:"8",padding_top:"8",text_color:"white",font_size:"16" do
      download(url_edit.text, save: "downloaded_image.png") do
        @status.replace "Download completed."
        @download_completed = true
      end
    end

    Thread.new do
      loop do
        sleep 2 # Add a short delay before checking @download_completed
        if @download_completed
          @status.replace "Showing you the image..."
          display_image("downloaded_image.png")
          break
        end
      end
    end
  end

  def display_image(image_path)
    image(image_path)
  end
end
