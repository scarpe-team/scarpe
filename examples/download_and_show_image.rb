# html_ci: false
# This is due to a button rendering issue

Shoes.app do
  stack do
    title "Downloading Google image", size: 16
    @status = para "Enter URL and press Enter:"

    url_edit = edit_line
    caption "here is a cute cat url: https://img.freepik.com/premium-photo/funny-smart-cat-professor-with-glasses-illustration-generative-ai_845977-709.jpg?w=700&h=300"

    button 'Download Image!', color: "#3d5a80", padding_bottom: "8", padding_top: "8", text_color: "white", font_size: "16" do
      download(url_edit.text, save: "downloaded_image.png") do
        @status.replace "Download completed. Click to display the image."
        @download_completed = true
        button 'Display Image', color: "#3d5a80", padding_bottom: "8", padding_top: "8", text_color: "white", font_size: "16" do
          if @download_completed
            @status.replace "Showing you the image..."
            display_image("downloaded_image.png")
          end
        end
      end
    end


  end

  def display_image(image_path)
    image(image_path)
  end
end
