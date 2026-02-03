# Button icon example - demonstrates icons on buttons
#
# The :icon option adds an image to a button alongside its text.
# Use :icon_pos to control icon placement: :left (default), :right, :top, :bottom

Shoes.app(title: "Button Icons Demo", width: 400, height: 350) do
  background "#EEE"
  
  # Sample icon URL (a simple placeholder)
  icon_url = "https://www.google.com/favicon.ico"
  
  stack margin: 20 do
    title "Button Icons Demo"
    
    para "Icons on buttons:", stroke: "#666"
    
    flow margin_bottom: 10 do
      button "Left Icon", icon: icon_url, icon_pos: :left do
        alert "Left icon clicked!"
      end
      
      button "Right Icon", icon: icon_url, icon_pos: :right do
        alert "Right icon clicked!"
      end
    end
    
    flow margin_bottom: 10 do
      button "Top Icon", icon: icon_url, icon_pos: :top do
        alert "Top icon clicked!"
      end
      
      button "Bottom Icon", icon: icon_url, icon_pos: :bottom do
        alert "Bottom icon clicked!"
      end
    end
    
    para "Regular button (no icon):", stroke: "#666", margin_top: 20
    button "No Icon" do
      alert "Regular button clicked!"
    end
  end
end
