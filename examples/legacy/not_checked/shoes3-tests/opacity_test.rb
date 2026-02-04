# App opacity example - demonstrates window transparency control
#
# The opacity property controls the transparency of the entire app window.
# Value ranges from 0.0 (fully transparent) to 1.0 (fully opaque).

Shoes.app(title: "App Opacity Demo", width: 400, height: 300) do
  background "#333"
  
  @current_opacity = 1.0
  
  stack margin: 20 do
    title "App Opacity Demo", stroke: white
    para "Click buttons to change window opacity.", stroke: "#AAA"
    
    @label = para "Opacity: 1.0 (100%)", stroke: lime, size: 16
    
    flow margin_top: 20 do
      button "100%" do
        @current_opacity = 1.0
        app.opacity = @current_opacity
        @label.replace("Opacity: #{@current_opacity} (100%)")
      end
      
      button "75%" do
        @current_opacity = 0.75
        app.opacity = @current_opacity
        @label.replace("Opacity: #{@current_opacity} (75%)")
      end
      
      button "50%" do
        @current_opacity = 0.5
        app.opacity = @current_opacity
        @label.replace("Opacity: #{@current_opacity} (50%)")
      end
      
      button "25%" do
        @current_opacity = 0.25
        app.opacity = @current_opacity
        @label.replace("Opacity: #{@current_opacity} (25%)")
      end
    end
    
    para "\nNote: Very low opacity may make the window hard to see!", stroke: yellow, margin_top: 20
  end
end
