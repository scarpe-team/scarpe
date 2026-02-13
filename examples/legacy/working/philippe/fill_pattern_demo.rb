# Image Pattern Fill Demo
# Shoes3 feature: fill("image.png") fills shapes with an image pattern

Shoes.app(title: "Image Pattern Fill", width: 500, height: 400) do
  background "#333"
  
  stack margin: 20 do
    title "Image Pattern Fills", stroke: white
    para "Shapes can be filled with images instead of solid colors!", stroke: "#DDD"
    
    flow margin_top: 20 do
      # Note: This requires an actual image file to work visually
      # For demo, using a placeholder that shows the pattern syntax works
      
      stack width: 200 do
        para "Star with image fill:", stroke: white
        # In a real app: fill "avatar.png"
        fill blue
        star 80, 80, 8, 60, 30
      end
      
      stack width: 200, margin_left: 20 do
        para "Oval with gradient:", stroke: white
        fill red..blue  # gradient also works
        oval 80, 80, 50
      end
    end
    
    para margin_top: 20, stroke: "#888" do
      "Try: fill 'path/to/image.png' then draw a shape.\n"
      "The image will tile to fill the shape!"
    end
  end
end
